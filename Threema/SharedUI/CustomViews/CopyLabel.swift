//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

@objc class CopyLabel: UILabel {
    @objc public var textForCopying: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        attachTapHandler()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        attachTapHandler()
    }
    
    func attachTapHandler() {
        isUserInteractionEnabled = true
        let recognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        
        addGestureRecognizer(recognizer)
    }
    
    @objc override func copy(_ sender: Any?) {
        if let textForCopying = textForCopying {
            UIPasteboard.general.string = textForCopying
        }
        else if let text = text {
            UIPasteboard.general.string = text
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(copy(_:))
    }

    @objc func handleTap(_ recognizer: UIGestureRecognizer?) {
        guard let superview = superview else {
            DDLogError("Could not handle tap because superview was nil")
            return
        }
        if !UIAccessibility.isVoiceOverRunning {
            becomeFirstResponder()
            let copyMenu = UIMenuController.shared
            copyMenu.update()
            copyMenu.setTargetRect(frame, in: superview)
            copyMenu.setMenuVisible(true, animated: true)
        }
    }

    override var canBecomeFirstResponder: Bool {
        true
    }
}
