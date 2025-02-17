//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import Combine
import Foundation
import ThreemaMacros

public protocol ReactionsManagerProtocol: AnyObject {
    func dismissContextMenu(showEmojiPicker: Bool, for reactionsManager: ReactionsManager)
    func showReactionAlert(for result: ReactionsManager.ReactionSendingResult)
    func showExistingReactions(reactionsManager: ReactionsManager)
}

/// Manages UI-Related functionality regarding reactions for a given base message
public class ReactionsManager: ObservableObject {
    
    public enum RecipientReactionSupport {
        case none, some, full
    }
    
    public enum ReactionSendingResult {
        case noSupportRemoteSingle, noSupportRemoteGroup, partialSupportRemoteGroup,
             success, noAction, unknownReaction, error
        
        public var alertTitle: String {
            switch self {
            case .success, .noAction:
                ""
            case .noSupportRemoteSingle:
                #localize("reaction_alert_title_unavailable")
            case .noSupportRemoteGroup:
                #localize("reaction_alert_title_unavailable")
            case .partialSupportRemoteGroup:
                #localize("reaction_alert_title_partial_support_remote_group")
            case .unknownReaction:
                #localize("reaction_alert_message_unknown_reaction")
            case .error:
                #localize("reaction_error_title")
            }
        }
        
        public var alertMessage: String {
            switch self {
            case .success, .noAction, .unknownReaction:
                ""
            case .noSupportRemoteSingle:
                #localize("reaction_alert_message_no_support_remote_single")
            case .noSupportRemoteGroup:
                #localize("reaction_alert_message_no_support_remote_group")
            case .partialSupportRemoteGroup:
                #localize("reaction_alert_message_partial_support_remote_group")
            case .error:
                #localize("reaction_error_message")
            }
        }
    }
    
    public enum ReactionError: Error {
        case sendingFailed
    }
    
    public struct ReactionInfo: Identifiable, Hashable {
        public let id = UUID()
        public let emoji: EmojiVariant?
        public let reactionString: String
        public let sortDate: Date
        public let count: Int
        public let contacts: Set<Contact?>
        public let canBeRemoved: Bool
        
        public init(
            reaction: String,
            sortDate: Date,
            contacts: Set<Contact?>,
            count: Int,
            canBeRemoved: Bool
        ) {
            self.emoji = EmojiVariant(rawValue: reaction)
            self.reactionString = reaction
            self.sortDate = sortDate
            self.contacts = contacts
            self.count = count
            self.canBeRemoved = canBeRemoved
        }
        
        public var displayValue: String {
            guard let emoji, emoji.base.isAvailable else {
                return "�"
            }
            return emoji.rawValue
        }
    }
    
    // MARK: - Public properties

    public let messageObjectID: NSManagedObjectID
   
    /// True if at least one recipient of the conversation of the message supports emoji reactions
    public lazy var recipientReactionSupport: RecipientReactionSupport = checkRecipientsEmojiSupport()
    
    public static var baseReactionEmojis: [EmojiVariant] {
        [
            ReactionsManager.preferredEmojiVariant(for: .thumbsUpSign),
            ReactionsManager.preferredEmojiVariant(for: .thumbsDownSign),
        ]
    }
    
    public static var defaultReactionEmojis: [EmojiVariant] {
        [
            .init(base: .heavyBlackHeart, skintone: nil),
            .init(base: .faceWithTearsOfJoy, skintone: nil),
            .init(base: .cryingFace, skintone: nil),
            ReactionsManager.preferredEmojiVariant(for: .personWithFoldedHands),
        ]
    }
    
    @Published public var currentReactions = [ReactionInfo]()
    
    // MARK: - Private properties

    private weak var reactionsManagerDelegate: ReactionsManagerProtocol?
    private lazy var businessInjector = BusinessInjector()
    private var reactionObserver: NSKeyValueObservation?
    
    // MARK: - Lifecycle
    
    public init(messageObjectID: NSManagedObjectID, reactionsManagerDelegate: ReactionsManagerProtocol) {
        self.messageObjectID = messageObjectID
        self.reactionsManagerDelegate = reactionsManagerDelegate
        observeReactions()
        
        let entityManager = businessInjector.entityManager
        entityManager.performAndWait { [self] in
            guard let message = entityManager.entityFetcher.existingObject(with: self.messageObjectID) as? BaseMessage
            else {
                return
            }
            updateCurrentReactions(for: message)
        }
    }
    
    deinit {
        reactionObserver?.invalidate()
    }
    
    private func observeReactions() {
        let entityManager = businessInjector.entityManager

        entityManager.performAndWait {
            guard let message = entityManager.entityFetcher.existingObject(with: self.messageObjectID) as? BaseMessage
            else {
                return
            }
            
            let observer = message.observe(\.reactions, options: [.new]) { [weak self] message, _ in
                
                self?.updateCurrentReactions(for: message)
            }
            self.reactionObserver = observer
        }
    }
    
    // MARK: - Public functions
    
    public func send(_ reaction: EmojiVariant?) {
        
        guard let reaction, reaction.base.isAvailable else {
            reactionsManagerDelegate?.showReactionAlert(for: .unknownReaction)
            return
        }
        
        let messageSender = businessInjector.messageSender
        reactionsManagerDelegate?.dismissContextMenu(showEmojiPicker: false, for: self)
        Task {
            do {
                let result = try await messageSender.sendReaction(
                    to: messageObjectID,
                    reaction: reaction
                )
                
                if result != .success, result != .noAction {
                    reactionsManagerDelegate?.showReactionAlert(for: result)
                }
            }
            catch {
                DDLogError("Send reaction message failed: \(error)")
            }
        }
        reactionsManagerDelegate?.dismissContextMenu(showEmojiPicker: false, for: self)
    }
    
    public func showEmojiPickerSheet() {
        reactionsManagerDelegate?.dismissContextMenu(showEmojiPicker: true, for: self)
    }
    
    public func showExistingReactions() {
        reactionsManagerDelegate?.showExistingReactions(reactionsManager: self)
    }
        
    public func isCurrentlySelected(emoji: EmojiVariant?) -> Bool {
        guard let emoji else {
            return false
        }
        
        let entityManager = businessInjector.entityManager
        return entityManager.performAndWait {
                
            guard let message = entityManager.entityFetcher
                .existingObject(with: self.messageObjectID) as? BaseMessage,
                let reactions = entityManager.entityFetcher.messageReactionEntities(
                    for: message,
                    creator: nil
                ) else {
                return false
            }
                
            // Check in reaction entities
            let containsReaction = reactions.contains(where: {
                $0.reaction == emoji.rawValue
            })
            return containsReaction
        }
    }
    
    /// The picker button is shown if the recipient has support.
    public func pickerButtonVisible() -> Bool {
        recipientReactionSupport != .none && !recipientHasGateWayID()
    }
    
    public func recipientHasGateWayID() -> Bool {
        let entityManager = businessInjector.entityManager
        return entityManager.performAndWait {
            guard let message = entityManager.entityFetcher
                .existingObject(with: self.messageObjectID) as? BaseMessage,
                !message.willBeDeleted,
                !message.conversation.isGroup,
                let contact = message.conversation.contact else {
                return false
            }
            
            return contact.isGatewayID()
        }
    }

    public func accessibilityActions() -> [UIAccessibilityCustomAction] {
        var actions = [UIAccessibilityCustomAction]()
        
        if pickerButtonVisible() {
            let openPickerAction =
                UIAccessibilityCustomAction(name: #localize("emoji_reaction_open_picker")) { [weak self] _ in
                    self?.showEmojiPickerSheet()
                    return true
                }
            
            actions.append(openPickerAction)
        }
        
        let emojis = recipientReactionSupport != .none ? ReactionsManager.baseReactionEmojis +
            ReactionsManager.defaultReactionEmojis : ReactionsManager.baseReactionEmojis
        
        for emoji in emojis.reversed() {
            actions.append(accessibilityAction(for: emoji))
        }
        
        if !currentReactions.isEmpty {
            let openExistingReactions =
                UIAccessibilityCustomAction(name: #localize(
                    "emoji_reaction_open_existing_reactions"
                )) { [weak self] _ in
                    
                    guard let self else {
                        return false
                    }
                    reactionsManagerDelegate?.showExistingReactions(reactionsManager: self)
                    return true
                }
            
            actions.append(openExistingReactions)
        }
        
        return actions
    }
    
    public func existingReactionsSummary() -> String? {
        
        guard !currentReactions.isEmpty else {
            return nil
        }
        
        var summary = #localize("emoji_reaction_summary_intro")
        
        for reaction in currentReactions {
            var element = String.localizedStringWithFormat(
                " \(#localize("emoji_reaction_summary_element")). ",
                reaction.emoji?.rawValue ?? #localize("emoji_reaction_summary_unknown"),
                "\(reaction.count)"
            )
            
            if let emoji = reaction.emoji, isCurrentlySelected(emoji: emoji) {
                element.append("\(#localize("emoji_reaction_summary_selected")). ")
            }
            summary.append(element)
        }
        return summary
    }
    
    public static func preferredEmojiVariant(for emoji: Emoji) -> EmojiVariant {
        EmojiVariant(
            base: emoji,
            skintone: .init(rawValue: UserSettings.shared().emojiVariantPreference[emoji.rawValue] ?? "")
        )
    }
    
    // MARK: - Private function

    private func messageHasNonLegacyMappableReactions() -> Bool {
        let entityManager = businessInjector.entityManager
        return entityManager.performAndWait {
            guard let message = entityManager.entityFetcher
                .existingObject(with: self.messageObjectID) as? BaseMessage
            else {
                return false
            }
               
            if let reactions = message.reactions, !reactions.isEmpty {
                
                for reaction in reactions {
                    if let emoji = Emoji(rawValue: reaction.reaction), emoji.applyLegacyMapping() != nil {
                        continue
                    }
                    return true
                }
            }
            return false
        }
    }
    
    private func updateCurrentReactions(for message: BaseMessage) {
        let entityManager = businessInjector.entityManager
        
        guard let reactions = entityManager.entityFetcher.messageReactionEntities(for: message) else {
            currentReactions.removeAll()
            return
        }
            
        var newReactions = Set<ReactionInfo>()
    
        for reaction in reactions {
            guard !reaction.willBeDeleted else {
                continue
            }
            
            let infoItem = newReactions.first { info in
                info.reactionString == reaction.reaction
            }
            
            var contact: Contact?
            if let creatorContact = reaction.creator {
                contact = Contact(contactEntity: creatorContact)
            }
            
            if let infoItem {
                newReactions.remove(infoItem)
                let date = infoItem.sortDate > reaction.date ? infoItem.sortDate : reaction.date
                var newContacts = infoItem.contacts
                newContacts.insert(contact)
                
                let newItem = ReactionInfo(
                    reaction: infoItem.reactionString,
                    sortDate: date,
                    contacts: newContacts,
                    count: infoItem.count + 1,
                    canBeRemoved: checkRecipientsEmojiSupport() != .none
                )
                newReactions.insert(newItem)
            }
            else {
                let newItem = ReactionInfo(
                    reaction: reaction.reaction,
                    sortDate: reaction.date,
                    contacts: [contact],
                    count: 1,
                    canBeRemoved: checkRecipientsEmojiSupport() != .none
                )
                newReactions.insert(newItem)
            }
        }
        let sorted = newReactions.sorted { $0.sortDate > $1.sortDate }
        currentReactions = sorted
    }
    
    private func checkRecipientsEmojiSupport() -> RecipientReactionSupport {
        let entityManager = businessInjector.entityManager
        return entityManager.performAndWait {
            guard let message = entityManager.entityFetcher
                .existingObject(with: self.messageObjectID) as? BaseMessage,
                !message.willBeDeleted
            else {
                return .none
            }
            
            let isNoteGroup = {
                guard !message.conversation.willBeDeleted, message.conversation.isGroup else {
                    return false
                }
                
                let businessInjector = BusinessInjector(forBackgroundProcess: true)
                
                guard let group = businessInjector.groupManager.getGroup(conversation: message.conversation),
                      group.isNoteGroup else {
                    return false
                }
                
                return true
            }()
            
            if isNoteGroup {
                return .full
            }
            
            let (supported, unsupported) = FeatureMask.check(message: message, for: .reactionSupport)
                
            if supported {
                if unsupported.isEmpty {
                    return .full
                }
                return .some
            }
            return .none
        }
    }
    
    private func accessibilityAction(for emoji: EmojiVariant) -> UIAccessibilityCustomAction {
        let name =
            if isCurrentlySelected(emoji: emoji) {
                String.localizedStringWithFormat(#localize("emoji_reaction_withdraw"), emoji.rawValue)
            }
            else {
                String.localizedStringWithFormat(#localize("emoji_reaction_apply"), emoji.rawValue)
            }
        
        let action = UIAccessibilityCustomAction(name: name) { [weak self] _ in
            self?.send(emoji)
            return true
        }
        
        return action
    }
}

// MARK: - ReactionsModalDelegate

extension ReactionsManager: ReactionsModalDelegate {
    public var currentReactionsByCreatorPublisher: AnyPublisher<[ReactionsManager.ReactionInfo], Never> {
        $currentReactions.eraseToAnyPublisher()
    }
}
