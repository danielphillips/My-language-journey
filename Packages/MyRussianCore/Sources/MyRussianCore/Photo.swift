import Foundation

public struct PixelSize: Equatable, Hashable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Word photos are memory aids, not keepsakes: stored small and heavily compressed.
public enum PhotoCompression {
    /// Longest side, in pixels.
    public static let maxDimension = 512
    /// JPEG quality (0–1).
    public static let jpegQuality = 0.5

    /// Size to render at: fits within `maxDimension`, keeps the aspect ratio, never upscales.
    public static func targetSize(for original: PixelSize, maxDimension: Int = maxDimension) -> PixelSize? {
        guard original.width > 0, original.height > 0 else { return nil }
        let longest = max(original.width, original.height)
        guard longest > maxDimension else { return original }
        let scale = Double(maxDimension) / Double(longest)
        return PixelSize(width: max(Int((Double(original.width) * scale).rounded(.down)), 1),
                         height: max(Int((Double(original.height) * scale).rounded(.down)), 1))
    }
}
