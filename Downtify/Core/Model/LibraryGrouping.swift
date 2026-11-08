import Foundation

public enum LibraryGrouping {
    
    public static func albums(from tracks: [Track]) -> [Album] {
        let validTracks = tracks.filter { !$0.albumId.isEmpty }
        let groups = Dictionary(grouping: validTracks, by: { $0.albumId })
        return groups.map { id, groupTracks in
            albumOf(id: id, group: groupTracks)
        }.sorted { $0.added > $1.added }
    }
    
    public static func artists(from tracks: [Track]) -> [Artist] {
        let validTracks = tracks.filter { !$0.artistId.isEmpty }
        let allAlbums = albums(from: validTracks)
        let albumsByArtist = Dictionary(grouping: allAlbums, by: { $0.artistId })
        let groups = Dictionary(grouping: validTracks, by: { $0.artistId })
        
        return groups.map { id, groupTracks in
            let artistAlbums = (albumsByArtist[id] ?? []).sorted { $0.year > $1.year }
            let sortedTracks = groupTracks.sorted {
                $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            }
            let name = mostCommon(groupTracks.map { $0.albumArtist })
            return Artist(
                id: id,
                name: name.isEmpty ? groupTracks.first?.displayArtist ?? "Unknown Artist" : name,
                albums: artistAlbums,
                tracks: sortedTracks
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    public static func albumOf(id: String, group: [Track]) -> Album {
        let sorted = group.sorted {
            let num0 = $0.trackNumber > 0 ? $0.trackNumber : Int.max
            let num1 = $1.trackNumber > 0 ? $1.trackNumber : Int.max
            if num0 != num1 { return num0 < num1 }
            return $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
        let title = mostCommon(sorted.map { $0.album })
        let artist = mostCommon(sorted.map { $0.albumArtist })
        let year = mostCommon(sorted.map { $0.year })
        let added = sorted.map { $0.added }.max() ?? 0
        let artistId = sorted.first?.artistId ?? ""
        
        return Album(
            id: id,
            title: title.isEmpty ? sorted.first?.album ?? "Untitled Album" : title,
            artist: artist.isEmpty ? sorted.first?.displayArtist ?? "Unknown Artist" : artist,
            artistId: artistId,
            year: year,
            tracks: sorted,
            added: added
        )
    }
    
    private static func mostCommon(_ values: [String]) -> String {
        let nonBlank = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var counts: [String: Int] = [:]
        for v in nonBlank {
            counts[v, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? ""
    }
}
