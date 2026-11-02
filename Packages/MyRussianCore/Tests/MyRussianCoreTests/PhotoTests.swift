import Testing
@testable import MyRussianCore

@Suite("Photo compression")
struct PhotoCompressionTests {
    @Test func photosAreStoredSmallBecauseTheyAreMemoryAidsNotKeepsakes() {
        #expect(PhotoCompression.maxDimension == 512)
        #expect(PhotoCompression.jpegQuality == 0.5)
    }

    @Test func landscapePhotoIsScaledToTheMaximumWidthKeepingItsShape() {
        #expect(PhotoCompression.targetSize(for: PixelSize(width: 4032, height: 3024)) == PixelSize(width: 512, height: 384))
    }

    @Test func portraitPhotoIsScaledToTheMaximumHeight() {
        #expect(PhotoCompression.targetSize(for: PixelSize(width: 3024, height: 4032)) == PixelSize(width: 384, height: 512))
    }

    @Test func smallPhotosAreNeverUpscaled() {
        #expect(PhotoCompression.targetSize(for: PixelSize(width: 300, height: 200)) == PixelSize(width: 300, height: 200))
    }

    @Test func dimensionsAreRoundedToWholePixelsAndNeverZero() {
        #expect(PhotoCompression.targetSize(for: PixelSize(width: 5000, height: 3)) == PixelSize(width: 512, height: 1))
        #expect(PhotoCompression.targetSize(for: PixelSize(width: 1000, height: 333)) == PixelSize(width: 512, height: 170))
    }

    @Test func emptyImagesProduceNoSize() {
        #expect(PhotoCompression.targetSize(for: PixelSize(width: 0, height: 100)) == nil)
    }
}
