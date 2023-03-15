//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

/// A `UITextView` subclass which automatically changes its textAlignment based on its content
/// This currently does not work for interactive UITextViews where the user can switch the input method
/// without having entered any text. See `ChatTextView` for how interactive UITextViews are handled.
/// It probably makes sense to handle interactive text views here as well instead of duplicating code.
class RTLAligningTextView: UITextView {
    override public var text: String! {
        didSet {
            if !text.isEmpty {
                self.textAlignment = text.textAlignment
            }
        }
    }

    override public var attributedText: NSAttributedString! {
        didSet {
            let text = attributedText.string
            if !text.isEmpty {
                textAlignment = text.textAlignment
            }
        }
    }
}
