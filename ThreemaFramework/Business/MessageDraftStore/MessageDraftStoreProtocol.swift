//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

public protocol MessageDraftStoreProtocol: AnyObject {
    static var shared: Self { get }
    
    /// Deletes the draft message associated with the given conversation.
    /// - Parameter conversation: The conversation for which the draft will be deleted.
    func deleteDraft(for conversation: ConversationEntity)
    
    /// Loads the draft message associated with the given conversation.
    /// - Parameter conversation: The conversation for which the draft will be loaded.
    /// - Returns: An optional `Draft` object if a draft exists, otherwise `nil`.
    func loadDraft(for conversation: ConversationEntity) -> Draft?
    
    /// Saves the draft message for a given conversation.
    /// - Parameters:
    ///   - draft: The `Draft` object to be saved.
    ///   - conversation: The conversation for which the draft will be saved.
    func saveDraft(_ draft: Draft, for conversation: ConversationEntity)
    
    /// Cleans up old draft messages that are no longer needed.
    /// This method checks if old drafts have already been deleted to avoid redundant cleanup.
    /// It iterates over all contacts and their conversations, collecting draft information.
    /// Finally, it updates the draft storage with the collected draft data.
    func cleanupDrafts()
    
    /// Generates a preview for the draft message associated with a given conversation.
    /// The preview is styled with the specified text style and tint color.
    /// - Parameters:
    ///   - conversation: The conversation for which the draft preview will be generated.
    ///   - textStyle: The font text style to be used for the preview.
    ///   - tint: The tint color to be applied to the preview text.
    /// - Returns: An optional `NSAttributedString` representing the styled draft preview, or `nil` if no draft is
    /// available.
    func previewForDraft(
        for conversation: ConversationEntity,
        textStyle: UIFont.TextStyle,
        tint: UIColor
    ) -> NSAttributedString?
}

extension MessageDraftStoreProtocol {
    public func previewForDraft(
        for conversation: ConversationEntity,
        textStyle: UIFont.TextStyle,
        tint: UIColor
    ) -> NSAttributedString? {
        guard let draft = loadDraft(for: conversation) else {
            return nil
        }
        let parsedDraft = MarkupParser()
            .previewString(for: draft.string, font: .preferredFont(forTextStyle: textStyle))
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
