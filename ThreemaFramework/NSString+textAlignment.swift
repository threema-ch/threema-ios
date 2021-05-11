//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

public extension NSString {
    @objc func textAlignment() -> NSTextAlignment {
        var lang: String?
        if #available(iOS 11.0, *) {
            lang = NSLinguisticTagger.dominantLanguage(for: self as String)
        } else {
            lang = CFStringTokenizerCopyBestStringLanguage(self as CFString, CFRange(location: 0, length: self.length)) as String
        }

        if let lang = lang {
            let direction = NSLocale.characterDirection(forLanguage: lang as String)

            if direction == .rightToLeft {
                return .right
            }
        }
        return .left
    }
}
