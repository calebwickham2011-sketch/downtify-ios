import Foundation

// MARK: - ListenEvent

private struct ListenEvent: Codable {
    let trackId: String
    let startedAt: Int64   // Unix ms
    let duration: Double   // seconds played before submission
}

// MARK: - ListenTracker

/// Tracks listen events per Downtify's rules:
///   • At least 30 seconds OR 50% of track played → submit a listen.
///   • Deduplicates within the same playback session.
///   • Queues events that fail to send and retries on the next flush.
public final class ListenTracker {

    // MARK: - State

    private var currentTrack: Track?
    private var sessionStart: Date?
    private var submitted: Bool = false
    private var pendingEvents: [ListenEvent] = []

    // Thresholds
    private let minSecondsThreshold: Double = 30
    private let minFractionThreshold: Double = 0.50

    // MARK: - Lifecycle Hooks (called by AudioPlayerManager)

    public init() {}

    /// Call when a new track starts playing.
    public func trackStarted(track: Track) {
        currentTrack = track
        sessionStart = Date()
        submitted = false
    }

    /// Call on every periodic time tick to check threshold crossing.
    public func tick(elapsed: Double, duration: Double) {
        guard !submitted, let track = currentTrack, duration > 0 else { return }

        let fractionPlayed = elapsed / duration
        let meetsThreshold = elapsed >= minSecondsThreshold || fractionPlayed >= minFractionThreshold

        if meetsThreshold {
            submitted = true
            submitListen(for: track)
        }
    }

    /// Call when a track ends (skipped or completed).
    public func trackFinished() {
        // If not yet submitted, do a final check
        if !submitted, let track = currentTrack, let start = sessionStart {
            let elapsed = Date().timeIntervalSince(start)
            let duration = track.duration
            let meetsThreshold = elapsed >= minSecondsThreshold ||
                (duration > 0 && elapsed / duration >= minFractionThreshold)
            if meetsThreshold {
                submitted = true
                submitListen(for: track)
            }
        }
        currentTrack = nil
        sessionStart = nil
    }

    // MARK: - Submission

    private func submitListen(for track: Track) {
        let event = ListenEvent(
            trackId: track.id,
            startedAt: Int64((sessionStart ?? Date()).timeIntervalSince1970 * 1000),
            duration: track.duration
        )
        pendingEvents.append(event)
        flushPending()
    }

    private func flushPending() {
        guard !pendingEvents.isEmpty else { return }
        let eventsToSend = pendingEvents
        pendingEvents = []

        Task.detached(priority: .background) { [weak self] in
            var failed: [ListenEvent] = []
            for event in eventsToSend {
                do {
                    try await ListenTracker.sendListen(event: event)
                } catch {
                    print("[ListenTracker] Failed to send listen for \(event.trackId): \(error)")
                    failed.append(event)
                }
            }
            if !failed.isEmpty {
                await MainActor.run { [weak self] in
                    self?.pendingEvents.insert(contentsOf: failed, at: 0)
                }
            }
        }
    }

    // MARK: - API Call

    private static func sendListen(event: ListenEvent) async throws {
        // KeychainSessionStore is @MainActor – hop over to grab session details.
        let sessionInfo: (baseUrl: String, token: String)? = await MainActor.run {
            guard let s = KeychainSessionStore.shared.session else { return nil }
            return (s.baseUrl, s.token)
        }
        guard let sessionInfo else { return }
        let cleanBase = sessionInfo.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/api/v1/listens") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sessionInfo.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "track_id": event.trackId,
            "started_at": event.startedAt,
            "duration": event.duration
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Flush on App Background

    /// Call from AppDelegate/SceneDelegate to flush queued events before the app suspends.
    public func flushBeforeBackground() {
        flushPending()
    }
}
