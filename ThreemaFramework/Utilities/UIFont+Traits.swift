//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation

@objc public extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0) // size 0 means keep the size as it is
    }

    func bold() -> UIFont {
        withTraits(traits: .traitBold)
    }

    func italic() -> UIFont {
        withTraits(traits: .traitItalic)
    }
    
    func traits() -> UIFontDescriptor.SymbolicTraits {
        fontDescriptor.symbolicTraits
    }

    func isBold() -> Bool {
        let traits = fontDescriptor.symbolicTraits
        return traits.contains(.traitBold) && !traits.contains(.traitItalic)
    }
    
    func isItalic() -> Bool {
        let traits = fontDescriptor.symbolicTraits
        return traits.contains(.traitItalic) && !traits.contains(.traitBold)
    }
    
    func isBoldItalic() -> Bool {
        let traits = fontDescriptor.symbolicTraits
        return traits.contains(.traitBold) && traits.contains(.traitItalic)
    }

    class func systemFont(fontSize: CGFloat, traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        UIFont.systemFont(ofSize: fontSize).including(traits: traits)
    }

    func including(traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        var _traits = fontDescriptor.symbolicTraits
        _traits.update(with: traits)
        return withOnly(traits: _traits)
    }

    func withOnly(traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let fontDescriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return nil
        }
        return .init(descriptor: fontDescriptor, size: pointSize)
    }
}
