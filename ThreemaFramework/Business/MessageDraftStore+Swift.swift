//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

public extension MessageDraftStore {
    
    static func previewForDraft(
        for conversation: Conversation,
        textStyle: UIFont.TextStyle,
        tint: UIColor
    ) -> NSAttributedString? {
        guard let draft = MessageDraftStore.loadDraft(for: conversation) else {
            return nil
        }
        let parsedDraft = MarkupParser()
            .previewString(for: draft, font: .preferredFont(forTextStyle: textStyle))
        let index = min(parsedDraft.length, 100)
        let trimmedDraft = parsedDraft.attributedSubstring(from: NSRange(location: 0, length: index))
        let mutableDraft = NSMutableAttributedString(attributedString: trimmedDraft)
        
        mutableDraft.removeAttribute(
            NSAttributedString.Key.link,
            range: NSRange(location: 0, length: mutableDraft.length)
        )
        mutableDraft.addAttributes(
            [NSAttributedString.Key.foregroundColor: tint],
            range: NSRange(location: 0, length: mutableDraft.length)
        )
        return mutableDraft
    }
}
