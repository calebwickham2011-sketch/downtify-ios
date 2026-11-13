import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

// MARK: - Player State

public enum PlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case error(String)
}

// MARK: - AudioPlayerManager

/// Central audio engine for Downtify iOS.
/// Manages AVQueuePlayer, AVAudioSession, MPNowPlayingInfoCenter,
/// MPRemoteCommandCenter, and authenticated streaming.
@MainActor
public final class AudioPlayerManager: NSObject, ObservableObject {

    // MARK: - Singleton
    public static let shared = AudioPlayerManager()

    // MARK: - Published State
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var queue: [Track] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public private(set) var state: PlayerState = .idle
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var isShuffled: Bool = false
    @Published public private(set) var repeatMode: RepeatMode = .off

    public enum RepeatMode { case off, one, all }

    // MARK: - Private AV Objects
    private var player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var playerItemObserver: AnyCancellable?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?

    // MARK: - Dependencies
    private let api = DowntifyAPI.shared
    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    private let listenTracker = ListenTracker()

    // MARK: - Init
    private override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        observeInterruptions()
        observeRouteChanges()
        addPeriodicTimeObserver()
    }

    // MARK: - Audio Session Setup

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[AudioPlayer] AVAudioSession setup failed: \(error)")
        }
    }

    // MARK: - Playback Control

    /// Load a new queue and start playing from the given index.
    public func play(queue tracks: [Track], startingAt index: Int = 0) {
        self.queue = tracks
        self.queueIndex = index
        playCurrentItem()
    }

    /// Convenience: play a single track immediately (replaces queue).
    public func play(track: Track) {
        play(queue: [track], startingAt: 0)
    }

    public func pause() {
        player.pause()
        state = .paused
        updateNowPlayingPlaybackState()
    }

    public func resume() {
        player.play()
        state = .playing
        updateNowPlayingPlaybackState()
    }

    public func togglePlayPause() {
        if state == .playing { pause() } else { resume() }
    }

    public func skipToNext() {
        let nextIndex: Int
        switch repeatMode {
        case .one:
            nextIndex = queueIndex
        case .all:
            nextIndex = (queueIndex + 1) % max(queue.count, 1)
        case .off:
            guard queueIndex + 1 < queue.count else {
                state = .idle
                return
            }
            nextIndex = queueIndex + 1
        }
        queueIndex = nextIndex
        playCurrentItem()
    }

    public func skipToPrevious() {
        // If more than 3 s in, restart; otherwise go back
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard queueIndex > 0 else {
            seek(to: 0)
            return
        }
        queueIndex -= 1
        playCurrentItem()
    }

    public func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = time
                self?.updateNowPlayingElapsedTime()
            }
        }
    }

    public func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled, let current = currentTrack {
            var rest = queue
            rest.remove(at: queueIndex)
            rest.shuffle()
            queue = [current] + rest
            queueIndex = 0
        }
    }

    public func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - Private Playback

    private func playCurrentItem() {
        guard queueIndex < queue.count else {
            state = .idle
            return
        }
        let track = queue[queueIndex]
        currentTrack = track
        state = .loading
        currentTime = 0

        guard let streamURL = api.streamUrl(trackId: track.id),
              let token = KeychainSessionStore.shared.session?.token else {
            state = .error("No stream URL or session")
            return
        }

        // Build authenticated asset
        let headers: [String: String] = ["Authorization": "Bearer \(token)"]
        let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)

        // Observe item status and end of playback
        observePlayerItem(item, for: track)

        player.replaceCurrentItem(with: item)
        player.play()

        // Fire now-playing metadata immediately (artwork loads async)
        updateNowPlayingMetadata(for: track)
        listenTracker.trackStarted(track: track)
    }

    // MARK: - KVO & Notifications

    private func observePlayerItem(_ item: AVPlayerItem, for track: Track) {
        statusObserver?.invalidate()
        durationObserver?.invalidate()

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.state = .playing
                    self.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                    self.updateNowPlayingMetadata(for: track)
                case .failed:
                    let msg = item.error?.localizedDescription ?? "Playback error"
                    self.state = .error(msg)
                default:
                    break
                }
            }
        }

        durationObserver = item.observe(\.duration, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                let d = item.duration.seconds
                if !d.isNaN && d > 0 { self?.duration = d }
            }
        }

        // End of item notification
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func playerItemDidEnd() {
        listenTracker.trackFinished()
        switch repeatMode {
        case .one:
            seek(to: 0)
            player.play()
        case .all, .off:
            skipToNext()
        }
    }

    // MARK: - Periodic Time Observer

    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.state == .playing else { return }
                let secs = time.seconds
                if !secs.isNaN {
                    self.currentTime = secs
                    self.listenTracker.tick(elapsed: secs, duration: self.duration)
                }
            }
        }
    }

    // MARK: - Interruption Handling (calls, Siri)

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        Task { @MainActor [weak self] in
            switch type {
            case .began:
                self?.pause()
            case .ended:
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.resume()
                    }
                }
            @unknown default: break
            }
        }
    }

    // MARK: - Route Change (AirPods unplug -> auto-pause)

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        // Pause on headphones/AirPods unplugged
        if reason == .oldDeviceUnavailable {
            Task { @MainActor [weak self] in self?.pause() }
        }
    }

    // MARK: - MPRemoteCommandCenter

    private func configureRemoteCommands() {
        remoteCommandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        remoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        remoteCommandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipToNext() }
            return .success
        }
        remoteCommandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipToPrevious() }
            return .success
        }
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                Task { @MainActor [weak self] in self?.seek(to: e.positionTime) }
            }
            return .success
        }

        // Enable/disable
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandCenter.skipForwardCommand.isEnabled = false
        remoteCommandCenter.skipBackwardCommand.isEnabled = false
    }

    // MARK: - MPNowPlayingInfoCenter

    private func updateNowPlayingMetadata(for track: Track) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayTitle,
            MPMediaItemPropertyArtist: track.displayArtist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration > 0 ? track.duration : duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        // Set placeholder artwork immediately, then fetch hi-res async
        nowPlayingCenter.nowPlayingInfo = info

        // Fetch cover art asynchronously
        if track.hasCover, let url = api.coverUrl(trackId: track.id, size: 600) {
            Task.detached(priority: .background) { [weak self] in
                guard let self else { return }
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let uiImage = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in uiImage }
                    await MainActor.run {
                        // Only set if same track is still playing
                        if self.currentTrack?.id == track.id {
                            info[MPMediaItemPropertyArtwork] = artwork
                            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentTime
                            self.nowPlayingCenter.nowPlayingInfo = info
                        }
                    }
                }
            }
        }
    }

    private func updateNowPlayingElapsedTime() {
        guard var info = nowPlayingCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackState() {
        guard var info = nowPlayingCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingCenter.nowPlayingInfo = info
    }

    // MARK: - Deinit

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
        statusObserver?.invalidate()
        durationObserver?.invalidate()
    }
}
