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

import CocoaLumberjackSwift
import Foundation

@objcMembers public class MessageDraftStore: NSObject {
    
    /// Deletes the draft message associated with the given conversation.
    /// - Parameter conversation: The conversation for which the draft will be deleted.
    public static func deleteDraft(for conversation: Conversation) {
        @MessageDraftCoordinator(conversation: conversation) var draft
        draft = nil
    }
    
    /// Loads the draft message associated with the given conversation.
    /// - Parameter conversation: The conversation for which the draft will be loaded.
    /// - Returns: An optional `Draft` object if a draft exists, otherwise `nil`.
    public static func loadDraft(for conversation: Conversation) -> Draft? {
        @MessageDraftCoordinator(conversation: conversation) var draft
        return draft
    }
    
    /// Saves the draft message for a given conversation.
    /// - Parameters:
    ///   - draft: The `Draft` object to be saved.
    ///   - conversation: The conversation for which the draft will be saved.
    public static func saveDraft(_ draft: Draft, for conversation: Conversation) {
        @MessageDraftCoordinator(conversation: conversation) var oldDraft
        oldDraft = draft
    }
    
    /// Cleans up old draft messages that are no longer needed.
    /// This method checks if old drafts have already been deleted to avoid redundant cleanup.
    /// It iterates over all contacts and their conversations, collecting draft information.
    /// Finally, it updates the draft storage with the collected draft data.
    public static func cleanupDrafts() {
        if let alreadyDeletedOldDrafts = MessageDraftCoordinator.MessageDraft.alreadyDeletedOldDrafts,
           alreadyDeletedOldDrafts {
            return
        }
        
        let entityManager = EntityManager()
        entityManager.performAndWait {
            var drafts: [Draft.Key: [String: String]] =
                Dictionary(uniqueKeysWithValues: zip(Draft.Key.allCases, Draft.Key.allCases.map { _ in
                    [String: String]()
                }))
            for contact in entityManager.entityFetcher.allContacts() as? [ContactEntity] ?? [] {
                for conv in contact.conversations as? Set<Conversation> ?? Set<Conversation>() {
                    @MessageDraftCoordinator(conversation: conv) var mdc
                    guard let mdc, let storeKey = $mdc.storeKey else {
                        return
                    }
                    
                    drafts[mdc.key]?[storeKey] = mdc.content
                }
            }
            
            drafts.forEach { (key: Draft.Key, value: [String: String]) in
                @MessageDraftCoordinator.MessageDraft(key: key) var draft
                draft = value
            }
        }
    }
    
    /// Generates a preview for the draft message associated with a given conversation.
    /// The preview is styled with the specified text style and tint color.
    /// - Parameters:
    ///   - conversation: The conversation for which the draft preview will be generated.
    ///   - textStyle: The font text style to be used for the preview.
    ///   - tint: The tint color to be applied to the preview text.
    /// - Returns: An optional `NSAttributedString` representing the styled draft preview, or `nil` if no draft is
    /// available.
    public static func previewForDraft(
        for conversation: Conversation,
        textStyle: UIFont.TextStyle,
        tint: UIColor
    ) -> NSAttributedString? {
        guard let draft = MessageDraftStore.loadDraft(for: conversation) else {
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

/// `Draft` is an abstraction for the message drafts when leaving a chat view.
/// To support new kinds of `Draft`, just add the desired `Key` and `Draft` cases.
/// Actual logic is handled by `MessageDraftCoordinator` completely unaware of the details defined here.
public enum Draft {
    public enum Key: String, CaseIterable {
        case messageDrafts = "MessageDrafts", audioMessageDrafts = "AudioMessageDrafts"
    }
    
    case text(String), audio(URL)
    
    /// Returns a string representation of the draft.
    public var string: String {
        switch self {
        case let .text(draft):
            draft
        case .audio:
            "file_message_voice".localized
        }
    }
    
    /// Initializes a new draft from a given key and value.
    /// - Parameters:
    ///   - key: The `Key` representing the type of draft to be initialized.
    ///   - value: The value associated with the draft, which could be a message draft, a file path for an audio draft
    /// or any future draft kinds
    /// - Returns: An optional `Draft` instance if initialization is successful, `nil` otherwise.
    init?(key: Key, value: String) {
        switch key {
        case .messageDrafts:
            self = .text(value)
        case .audioMessageDrafts:
            guard let path = URL(string: "file://\(value)") else {
                return nil
            }
            
            self = .audio(path)
        }
    }
    
    fileprivate var key: Key {
        switch self {
        case .text:
            Key.messageDrafts
        case .audio:
            Key.audioMessageDrafts
        }
    }
    
    fileprivate var content: String? {
        switch self {
        case let .text(draft):
            draft
        case let .audio(draft):
            draft.path
        }
    }
    
    /// Delete Draft contents
    fileprivate func delete() {
        DDLogInfo("draft deleted: \(self)")
        DispatchQueue.global(qos: .background).async {
            switch self {
            case let .audio(draft):
                guard !isEmpty else {
                    return
                }
                do {
                    try FileManager.default.removeItem(atPath: draft.path)
                }
                catch {
                    DDLogError("\(error)")
                }
            default:
                // Text is not stored on disk, future drafts might
                break
            }
        }
    }
    
    private var isEmpty: Bool {
        switch self {
        case let .text(draft):
            draft.isEmpty
        case let .audio(draft):
            !FileManager.default.fileExists(atPath: draft.path)
        }
    }
}

// MARK: - Equatable

extension Draft: Equatable {
    public static func == (rhs: Draft, lhs: Draft) -> Bool {
        rhs.content == lhs.content && rhs == lhs
    }
}

/// A property wrapper for managing message drafts associated with a conversation.
/// It provides a getter and setter to handle the retrieval and storage of drafts.
/// The getter fetches the first available draft for the given `storeKey`.
/// The setter updates the draft storage, deleting any existing drafts if a new value is set to `nil`,
///
/// Everything here should work with any types of `Draft`
@propertyWrapper struct MessageDraftCoordinator {
    let conversation: Conversation
    
    var projectedValue: MessageDraftCoordinator { self }
    
    var wrappedValue: Draft? {
        get {
            loadDraft()
        }
        set {
            guard let storeKey else {
                return
            }
            
            defer { post() }

            guard let newValue else {
                // New value is Empty, delete everything
                Draft.Key.allCases.forEach {
                    @MessageDraft(key: $0) var draft
                    $draft.load(storeKey: storeKey)?.delete()
                    draft.removeValue(forKey: storeKey)
                        .map { deletedDraft in
                            DDLogInfo("deleted draft \(deletedDraft)")
                        }
                }
                return
            }
            
            // Delete everything, skip if draft has not changed
            Draft.Key
                .allCases
                .compactMap {
                    @MessageDraft(key: $0) var tmp
                    let loaded = $tmp.load(storeKey: storeKey)
                    tmp.removeValue(forKey: storeKey)
                        .map { deletedDraft in
                            DDLogInfo("deleted draft \(deletedDraft)")
                        }
                    return loaded
                }
                .forEach { $0.delete() }
            
            // Save draft
            @MessageDraft(key: newValue.key) var draft
            draft[storeKey] = newValue.content
            DDLogInfo("saved draft \(newValue.string): \(newValue)")
        }
    }
    
    fileprivate func loadDraft() -> Draft? {
        guard let storeKey else {
            return nil
        }
        
        let drafts: [MessageDraft] = Draft.Key.allCases.compactMap {
            @MessageDraft(key: $0) var draft
            guard let _ = draft[storeKey] else {
                return nil
            }
            return $draft
        }
        
        return drafts.first?.load(storeKey: storeKey)
    }
    
    fileprivate var storeKey: String? {
        if conversation.isGroup(), let hexStr = conversation.groupID?.hexString {
            let creator = conversation.contact?.identity ?? "*"
            return "\(creator)-\(hexStr)"
        }
        else {
            return conversation.contact?.identity
        }
    }
    
    private func post() {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: kNotificationUpdateDraftForCell),
            object: nil,
            userInfo: [kKeyConversation: conversation]
        )
    }
    
    /// UserDefaults Helper
    @propertyWrapper struct MessageDraft {
        let key: Draft.Key
  
        var projectedValue: MessageDraft { self }
        
        var wrappedValue: [String: String] {
            get {
                AppGroup.userDefaults().dictionary(forKey: key.rawValue) as? [String: String] ?? [:]
            }
            set {
                AppGroup.userDefaults().set(newValue, forKey: key.rawValue)
                AppGroup.userDefaults().synchronize()
            }
        }
        
        static var alreadyDeletedOldDrafts: Bool? {
            get {
                AppGroup.userDefaults()?.bool(forKey: "AlreadyDeletedOldDrafts")
            }
            set {
                guard let newValue else {
                    AppGroup.userDefaults().removeObject(forKey: "AlreadyDeletedOldDrafts")
                    return
                }
                AppGroup.userDefaults().set(newValue, forKey: "AlreadyDeletedOldDrafts")
                AppGroup.userDefaults().synchronize()
            }
        }
        
        func load(storeKey: String) -> Draft? {
            guard
                let draftValue = wrappedValue[storeKey]
            else {
                return nil
            }
            
            return Draft(key: key, value: draftValue)
        }
    }
}
