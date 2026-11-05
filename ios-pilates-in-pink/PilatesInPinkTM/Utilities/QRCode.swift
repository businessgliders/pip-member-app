import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// On-device QR generation for the member card (display only).
enum QRCode {
    static func image(for string: String, foreground: UIColor, background: UIColor) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let colored = CIFilter.falseColor()
        colored.inputImage = output
        colored.color0 = CIColor(color: foreground)
        colored.color1 = CIColor(color: background)
        guard let tinted = colored.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else { return nil }

        let context = CIContext()
        guard let cg = context.createCGImage(tinted, from: tinted.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
