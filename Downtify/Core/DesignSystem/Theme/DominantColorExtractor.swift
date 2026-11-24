import UIKit
import SwiftUI

/// Extracts vibrant and background gradient colors from an artwork UIImage.
@MainActor
public final class DominantColorExtractor {
    public static let shared = DominantColorExtractor()
    
    // In-memory cache for extracted colors by track ID or image hash
    private var cache: [String: (Color, Color)] = [:]
    
    private init() {}
    
    /// Returns a tuple of (primaryAccent, backgroundAmbient) colors for an image.
    public func extractColors(from image: UIImage, key: String? = nil) -> (primary: Color, background: Color) {
        if let key = key, let cached = cache[key] {
            return cached
        }
        
        let size = CGSize(width: 24, height: 24)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = resizedImage?.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            let fallback = (Color.purple.opacity(0.8), Color.black)
            if let key = key { cache[key] = fallback }
            return fallback
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        
        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        var sampleCount: Double = 0
        
        var maxVibrancy: Double = -1
        var vibrantR: Double = 0.2
        var vibrantG: Double = 0.2
        var vibrantB: Double = 0.3
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Double(bytes[offset]) / 255.0
                let g = Double(bytes[offset + 1]) / 255.0
                let b = Double(bytes[offset + 2]) / 255.0
                
                totalR += r
                totalG += g
                totalB += b
                sampleCount += 1
                
                // Calculate color vibrancy (saturation * brightness)
                let maxVal = max(r, max(g, b))
                let minVal = min(r, min(g, b))
                let delta = maxVal - minVal
                let saturation = maxVal == 0 ? 0 : delta / maxVal
                let vibrancy = saturation * maxVal
                
                if vibrancy > maxVibrancy && maxVal > 0.25 {
                    maxVibrancy = vibrancy
                    vibrantR = r
                    vibrantG = g
                    vibrantB = b
                }
            }
        }
        
        let avgR = sampleCount > 0 ? totalR / sampleCount : 0.2
        let avgG = sampleCount > 0 ? totalG / sampleCount : 0.2
        let avgB = sampleCount > 0 ? totalB / sampleCount : 0.2
        
        // Enhance vibrancy for primary accent
        let primaryColor = Color(
            red: max(0.15, min(vibrantR * 1.1, 0.95)),
            green: max(0.15, min(vibrantG * 1.1, 0.95)),
            blue: max(0.15, min(vibrantB * 1.1, 0.95))
        )
        
        // Deep ambient background tone
        let bgAmbient = Color(
            red: max(0.04, min(avgR * 0.35, 0.20)),
            green: max(0.04, min(avgG * 0.35, 0.20)),
            blue: max(0.04, min(avgB * 0.35, 0.22))
        )
        
        let result = (primaryColor, bgAmbient)
        if let key = key {
            cache[key] = result
        }
        return result
    }
}
