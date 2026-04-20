import Foundation
import NaturalLanguage

extension String {
    public var textAlignment: NSTextAlignment {
        if let lang = NLLanguageRecognizer.dominantLanguage(for: self)?.rawValue {
            let direction = NSLocale.characterDirection(forLanguage: lang)

            if direction == .rightToLeft {
                return .right
            }
        }
        return .left
    }
}
