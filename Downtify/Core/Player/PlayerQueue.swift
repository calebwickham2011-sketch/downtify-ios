import Foundation

/// Mathematical queue operations matching Downtify Android's `PlayQueue.kt`.
public enum PlayQueueMath {
    /// The item a newly queued song goes right after.
    public static func anchor(playOrder: [Int], isQueued: (Int) -> Bool) -> Int? {
        if playOrder.isEmpty { return nil }
        var last = 0
        while last + 1 < playOrder.count && isQueued(playOrder[last + 1]) {
            last += 1
        }
        return playOrder[last]
    }
    
    /// Shuffle order after an item is appended at newIndex.
    public static func shuffleOrderWith(order: [Int], anchor: Int, newIndex: Int) -> [Int] {
        guard let at = order.firstIndex(of: anchor) else {
            return order + [newIndex]
        }
        return Array(order[0...at]) + [newIndex] + Array(order[(at + 1)...])
    }
    
    /// Moves an item right after anchor.
    public static func moveAfter(order: [Int], item: Int, anchor: Int) -> [Int] {
        if item == anchor { return order }
        let without = order.filter { $0 != item }
        guard let at = without.firstIndex(of: anchor) else { return order }
        return Array(without[0...at]) + [item] + Array(without[(at + 1)...])
    }
    
    /// Index target for move operations.
    public static func moveTarget(from: Int, anchor: Int) -> Int {
        from < anchor ? anchor : anchor + 1
    }
    
    /// Whether a song moved between two others should count as manually queued.
    public static func queuedAfterMove(previousQueued: Bool?, nextQueued: Bool?, wasQueued: Bool) -> Bool {
        if previousQueued == false { return false }
        if nextQueued == true { return true }
        return wasQueued
    }
}

/// Rich queue model managing ordered tracks, manual queues, history, shuffle, and reordering.
public struct PlayerQueue {

    // MARK: - Storage

    private var original: [Track] = []  // un-shuffled master order
    private var effective: [Track] = [] // what the player actually sees
    public private(set) var index: Int = 0
    public private(set) var userQueuedIds: Set<String> = []

    // MARK: - Accessors

    public var tracks: [Track] { effective }
    public var current: Track? { effective.indices.contains(index) ? effective[index] : nil }
    public var isEmpty: Bool { effective.isEmpty }
    public var count: Int { effective.count }

    /// Tracks played before the current position (History).
    public var history: [Track] {
        guard index > 0 else { return [] }
        return Array(effective[0..<min(index, effective.count)])
    }

    /// Tracks remaining after the current one (Upcoming / Up Next).
    public var upcoming: [Track] {
        guard index + 1 < effective.count else { return [] }
        return Array(effective[(index + 1)...])
    }
    
    public func isQueued(trackId: String) -> Bool {
        userQueuedIds.contains(trackId)
    }

    // MARK: - Mutations

    /// Replace the entire queue and reset the index.
    public mutating func setQueue(_ tracks: [Track], startAt: Int = 0, shuffled: Bool = false) {
        original = tracks
        userQueuedIds.removeAll()
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

    /// Insert a track immediately after the current position or after last queued item.
    public mutating func insertNext(_ track: Track) {
        let insertPos = min(index + 1, effective.count)
        effective.insert(track, at: insertPos)
        original.append(track)
        userQueuedIds.insert(track.id)
    }

    /// Append a track to the end of the queue.
    public mutating func append(_ track: Track) {
        effective.append(track)
        original.append(track)
        userQueuedIds.insert(track.id)
    }

    /// Remove a track at a given position.
    public mutating func remove(at pos: Int) {
        guard effective.indices.contains(pos) else { return }
        let removed = effective.remove(at: pos)
        userQueuedIds.remove(removed.id)
        if pos < index {
            index -= 1
        } else if pos == index && index >= effective.count {
            index = max(0, effective.count - 1)
        }
    }
    
    /// Reorder upcoming tracks (relative to the upcoming section).
    public mutating func moveUpcoming(fromOffsets: IndexSet, toOffset: Int) {
        let upcomingStart = index + 1
        guard upcomingStart < effective.count else { return }
        
        var upcomingSlice = Array(effective[upcomingStart...])
        upcomingSlice.move(fromOffsets: fromOffsets, toOffset: toOffset)
        
        effective = Array(effective[0...index]) + upcomingSlice
    }
    
    /// Jump directly to a given absolute track index.
    public mutating func jumpTo(index: Int) {
        guard effective.indices.contains(index) else { return }
        self.index = index
    }
    
    /// Clear all upcoming tracks after the current one.
    public mutating func clearUpcoming() {
        guard index < effective.count else { return }
        effective = Array(effective[0...index])
        userQueuedIds.removeAll()
    }

    /// Advance to the next track. Returns false if at end and repeat is off.
    public mutating func advance(repeat mode: AudioPlayerManager.RepeatMode) -> Bool {
        switch mode {
        case .one:
            return true
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
