import Foundation

/// A single timestamped line of lyrics.
public struct LyricLine: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let timeMs: Int64
    public let text: String
    
    public init(id: String = UUID().uuidString, timeMs: Int64, text: String) {
        self.id = id
        self.timeMs = timeMs
        self.text = text
    }
}

/// A track's lyrics: time-synced lines when an LRC is available, else plain text.
public struct Lyrics: Equatable, Sendable {
    public let synced: [LyricLine]
    public let plain: String
    
    public init(synced: [LyricLine] = [], plain: String = "") {
        self.synced = synced
        self.plain = plain
    }
    
    public var isEmpty: Bool {
        synced.isEmpty && plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var isSynced: Bool {
        !synced.isEmpty
    }
    
    public var text: String {
        let trimmedPlain = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPlain.isEmpty {
            return trimmedPlain
        }
        return synced.map { $0.text }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static let empty = Lyrics(synced: [], plain: "")
}

/// Fine-tuning synced lyrics timing against the audio track.
public enum LyricsTiming {
    public static let stepMs: Int64 = 250
    public static let maxMs: Int64 = 15_000
    
    public static func clamp(offsetMs: Int64) -> Int64 {
        min(max(offsetMs, -maxMs), maxMs)
    }
    
    public static func shift(lines: [LyricLine], offsetMs: Int64) -> [LyricLine] {
        if offsetMs == 0 { return lines }
        return lines.map { LyricLine(id: $0.id, timeMs: max(0, $0.timeMs + offsetMs), text: $0.text) }
    }
    
    public static func seconds(offsetMs: Int64) -> String {
        let sign = offsetMs > 0 ? "+" : (offsetMs < 0 ? "-" : "")
        let absSec = Double(abs(offsetMs)) / 1000.0
        return "\(sign)\(String(format: "%.2f", absSec))"
    }
}

/// Parser for `.lrc` lyrics format with timestamps like `[mm:ss.xx]`, multiple timestamps, and `[offset:±ms]`.
public enum LrcParser {
    // Matches [mm:ss], [mm:ss.xx], [mm:ss.xxx], or [m:ss:xx]
    private static let stampRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]"#,
        options: []
    )
    private static let offsetRegex = try! NSRegularExpression(
        pattern: #"^\[offset:\s*([+-]?\d+)\s*\]"#,
        options: [.caseInsensitive]
    )
    
    public static func parse(lrc: String) -> [LyricLine] {
        var offset: Int64 = 0
        var lines: [LyricLine] = []
        
        let rawLines = lrc.components(separatedBy: .newlines)
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            // Check for [offset:±ms]
            let lineRange = NSRange(location: 0, length: line.utf16.count)
            if let offsetMatch = offsetRegex.firstMatch(in: line, options: [], range: lineRange) {
                if let r = Range(offsetMatch.range(at: 1), in: line) {
                    offset = Int64(line[r]) ?? 0
                }
            }
            
            // Find all timestamps in this line
            var stamps: [Int64] = []
            var lastStampEnd = 0
            
            let matches = stampRegex.matches(in: line, options: [], range: lineRange)
            for match in matches {
                // Ensure timestamps are consecutive from the start or current position
                if match.range.location >= lastStampEnd {
                    stamps.append(toMillis(line: line, match: match))
                    lastStampEnd = match.range.location + match.range.length
                }
            }
            
            if stamps.isEmpty { continue }
            
            let textStartIndex = line.index(line.startIndex, offsetBy: min(lastStampEnd, line.count))
            let text = String(line[textStartIndex...]).trimmingCharacters(in: .whitespaces)
            
            for stamp in stamps {
                let adjustedTime = max(0, stamp - offset)
                lines.append(LyricLine(timeMs: adjustedTime, text: text))
            }
        }
        
        return lines.sorted { $0.timeMs < $1.timeMs }
    }
    
    /// Returns the index of the line currently active at `positionMs`, or -1 if before the first line.
    public static func activeIndex(lines: [LyricLine], positionMs: Int64) -> Int {
        var low = 0
        var high = lines.count - 1
        var found = -1
        
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].timeMs <= positionMs {
                found = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return found
    }
    
    /// Milliseconds until the next line starts, or nil if currently singing the last line.
    public static func nextLineInMs(lines: [LyricLine], positionMs: Int64) -> Int64? {
        let current = activeIndex(lines: lines, positionMs: positionMs)
        guard current + 1 < lines.count else { return nil }
        return lines[current + 1].timeMs - positionMs
    }
    
    private static func toMillis(line: String, match: NSTextCheckingResult) -> Int64 {
        var min: Int64 = 0
        var sec: Int64 = 0
        var fraction: Int64 = 0
        
        if let r = Range(match.range(at: 1), in: line) {
            min = Int64(line[r]) ?? 0
        }
        if let r = Range(match.range(at: 2), in: line) {
            sec = Int64(line[r]) ?? 0
        }
        if match.numberOfRanges > 3, let r = Range(match.range(at: 3), in: line) {
            let fracStr = String(line[r])
            switch fracStr.count {
            case 1:
                fraction = (Int64(fracStr) ?? 0) * 100
            case 2:
                fraction = (Int64(fracStr) ?? 0) * 10
            default:
                fraction = Int64(fracStr.prefix(3)) ?? 0
            }
        }
        
        return min * 60_000 + sec * 1_000 + fraction
    }
}
