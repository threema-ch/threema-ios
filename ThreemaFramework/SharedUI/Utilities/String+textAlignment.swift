import CoreText
import Foundation

extension String {
    public var textAlignment: NSTextAlignment {
        let deviceLocaleAlignment: NSTextAlignment = Locale.current.language.characterDirection == .rightToLeft ? .right : .left

        guard !isEmpty else {
            return deviceLocaleAlignment
        }

        for scalar in unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else {
                continue
            }
            let v = scalar.value
            if (v >= 0x0590 && v <= 0x08FF) ||
                (v >= 0xFB1D && v <= 0xFDFF) ||
                (v >= 0xFE70 && v <= 0xFEFF) {
                return .right
            }
            return .left
        }
        return deviceLocaleAlignment
    }
}
