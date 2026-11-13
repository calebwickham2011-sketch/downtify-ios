import Foundation

/// Lightweight value-type queue model that AudioPlayerManager uses
/// to manage ordered tracks, shuffle, and "play next" insertion.
public struct PlayerQueue {

    // MARK: - Storage

    private var original: [Track] = []  // un-shuffled master order
    private var effective: [Track] = [] // what the player actually sees
    public private(set) var index: Int = 0

    // MARK: - Accessors

    public var tracks: [Track] { effective }
    public var current: Track? { effective.indices.contains(index) ? effective[index] : nil }
    public var isEmpty: Bool { effective.isEmpty }
    public var count: Int { effective.count }

    /// Tracks remaining after the current one.
    public var upcoming: [Track] {
        guard index + 1 < effective.count else { return [] }
        return Array(effective[(index + 1)...])
    }

    // MARK: - Mutations

    /// Replace the entire queue and reset the index.
    public mutating func setQueue(_ tracks: [Track], startAt: Int = 0, shuffled: Bool = false) {
        original = tracks
        if shuffled {
            var copy = tracks
            if copy.indices.contains(startAt) {
                let first = copy.remove(at: startAt)
                copy.shuffle()
                effective = [first] + copy
                index = 0
            } else {
                copy.shuffle()
                effective = copy
                index = 0
            }
        } else {
            effective = tracks
            index = startAt
        }
    }

    /// Insert a track immediately after the current position (play-next).
    public mutating func insertNext(_ track: Track) {
        let insertPos = min(index + 1, effective.count)
        effective.insert(track, at: insertPos)
    }

    /// Append a track to the end of the queue.
    public mutating func append(_ track: Track) {
        effective.append(track)
    }

    /// Remove a track at a given position (skipping current if it would shift index).
    public mutating func remove(at pos: Int) {
        guard effective.indices.contains(pos) else { return }
        effective.remove(at: pos)
        if pos < index { index -= 1 }
        index = max(0, min(index, effective.count - 1))
    }

    /// Advance to the next track. Returns false if at end and repeat is off.
    public mutating func advance(repeat mode: AudioPlayerManager.RepeatMode) -> Bool {
        switch mode {
        case .one:
            return true  // stay at same index; caller re-plays current
        case .all:
            index = (index + 1) % max(effective.count, 1)
            return true
        case .off:
            if index + 1 < effective.count {
                index += 1
                return true
            }
            return false
        }
    }

    /// Go back one track.
    public mutating func retreat() {
        if index > 0 { index -= 1 }
    }

    /// Re-shuffle keeping current track at front.
    public mutating func reshuffle() {
        guard let current else { return }
        var rest = effective
        rest.remove(at: index)
        rest.shuffle()
        effective = [current] + rest
        index = 0
    }

    /// Restore the original un-shuffled order, keeping current track.
    public mutating func unshuffle() {
        guard let current else {
            effective = original
            index = 0
            return
        }
        effective = original
        index = effective.firstIndex(where: { $0.id == current.id }) ?? 0
    }
}
