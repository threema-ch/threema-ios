import Foundation

@objc extension UIFont {
    public func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0) // size 0 means keep the size as it is
    }

    public func bold() -> UIFont {
        withTraits(traits: .traitBold)
    }

    public func italic() -> UIFont {
        withTraits(traits: .traitItalic)
    }
    
    public func traits() -> UIFontDescriptor.SymbolicTraits {
        fontDescriptor.symbolicTraits
    }

    public func isBold() -> Bool {
        let traits = fontDescriptor.symbolicTraits
        return traits.contains(.traitBold) && !traits.contains(.traitItalic)
    }
    
    public func isItalic() -> Bool {
        let traits = fontDescriptor.symbolicTraits
        return traits.contains(.traitItalic) && !traits.contains(.traitBold)
    }
    
    public func isBoldItalic() -> Bool {
        let traits = fontDescriptor.symbolicTraits
        return traits.contains(.traitBold) && traits.contains(.traitItalic)
    }

    public class func systemFont(fontSize: CGFloat, traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        UIFont.systemFont(ofSize: fontSize).including(traits: traits)
    }

    public func including(traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        var _traits = fontDescriptor.symbolicTraits
        _traits.update(with: traits)
        return withOnly(traits: _traits)
    }

    public func withOnly(traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let fontDescriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return nil
        }
        return .init(descriptor: fontDescriptor, size: pointSize)
    }
}
