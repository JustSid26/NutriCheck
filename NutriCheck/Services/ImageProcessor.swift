import UIKit

@MainActor
enum ImageProcessor {
    /// Downscales (and normalizes orientation) for upload. 1600px keeps label text legible.
    static func uploadJPEG(from image: UIImage) -> Data? {
        resized(image, maxDimension: 1600).jpegData(compressionQuality: 0.8)
    }

    /// Small copy stored with the log entry.
    static func thumbnailJPEG(from image: UIImage) -> Data? {
        resized(image, maxDimension: 600).jpegData(compressionQuality: 0.7)
    }

    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
