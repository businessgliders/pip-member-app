import CoreText
import UIKit

/// Registers the bundled DM Sans faces at first use. If anything fails, `isAvailable`
/// is false and typography falls back to SF Pro.
enum FontRegistrar {
    static let faces = ["DMSans-Light", "DMSans-Regular", "DMSans-Medium"]

    static let isAvailable: Bool = {
        for name in faces where UIFont(name: name, size: 12) == nil {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return faces.allSatisfy { UIFont(name: $0, size: 12) != nil }
    }()
}
