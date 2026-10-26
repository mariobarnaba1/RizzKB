import UIKit

enum ImageTools {
    /// Downscales a screenshot so it's small enough for a keyboard extension's
    /// tight memory limit but still sharp enough for the model to read the text.
    static func jpegForUpload(_ image: UIImage, maxDimension: CGFloat = 1600) -> Data? {
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        guard pixelW > 0, pixelH > 0 else { return nil }
        let ratio = min(1, maxDimension / max(pixelW, pixelH))
        let target = CGSize(width: floor(pixelW * ratio), height: floor(pixelH * ratio))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }
}
