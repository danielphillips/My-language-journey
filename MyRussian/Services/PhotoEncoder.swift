import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers
import MyRussianCore

/// Turns a picked photo into a small JPEG (see `PhotoCompression` for the limits).
enum PhotoEncoder {
    /// Downsamples straight from the encoded data with ImageIO, so a 12 MP photo is never fully decoded.
    static func compressedJPEG(fromImageData data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // respect EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: PhotoCompression.maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return jpeg(from: thumbnail)
    }

    /// For images already in memory.
    static func compressedJPEG(from image: UIImage) -> Data? {
        let pixels = PixelSize(width: Int(image.size.width * image.scale), height: Int(image.size.height * image.scale))
        guard let target = PhotoCompression.targetSize(for: pixels) else { return nil }
        let size = CGSize(width: target.width, height: target.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: PhotoCompression.jpegQuality)
    }

    private static func jpeg(from image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: PhotoCompression.jpegQuality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Solid-colour test image.
    static func render(color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
