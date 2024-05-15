//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

    // TODO: (IOS-4156) All code below is needed due to a bug which causes text to be cut of when the device language is set to german. The changes enforce the use of TextKit1. Last tested iOS 17.4.1
    var customLayoutManager = NSLayoutManager()

    override var layoutManager: NSLayoutManager {
        customLayoutManager
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        initCustomLayoutManager()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initCustomLayoutManager()
    }

    private func initCustomLayoutManager() {
        if #available(iOS 17, *) {
            customLayoutManager.textStorage = textStorage
            customLayoutManager.addTextContainer(self.textContainer)

            self.textContainer.replaceLayoutManager(customLayoutManager)
        }
        else {
            customLayoutManager = super.layoutManager
        }
    }
}
