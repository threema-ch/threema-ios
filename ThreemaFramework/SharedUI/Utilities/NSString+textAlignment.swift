import Foundation
import NaturalLanguage

extension NSString {
    @objc public func textAlignment() -> NSTextAlignment {
        if let lang = NLLanguageRecognizer.dominantLanguage(for: self as String)?.rawValue {
            let direction = NSLocale.characterDirection(forLanguage: lang)

            if direction == .rightToLeft {
                return .right
            }
        }
        return .left
    }
}
