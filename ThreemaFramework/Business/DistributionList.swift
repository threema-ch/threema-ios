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

/// Business representation of a Threema distribution list
public class DistributionList: NSObject {
    
    // MARK: - Public properties

    public let distributionListID: Int
    
    @objc public private(set) dynamic var profilePicture: Data?
    @objc public private(set) dynamic var displayName: String?
    @objc public private(set) dynamic var recipients = Set<Contact>()

    public var recipientsSummary: String {
        guard !recipients.isEmpty else {
            return "distribution_list_no_recipient_title".localized
        }
        
        return ListFormatter.localizedString(byJoining: recipients.map(\.shortDisplayName))
    }
    
    public var numberOfRecipients: Int {
        recipients.count
    }
    
    public var recipientCountString: String {
        if numberOfRecipients == 1 {
            "distribution_list_one_recipient_title".localized
        }
        else {
            String.localizedStringWithFormat(
                "distribution_list_multiple_recipients_title".localized,
                numberOfRecipients
            )
        }
    }
    
    @objc public private(set) dynamic var willBeDeleted = false
    
    // MARK: - Private properties
    
    // Tokens for entity subscriptions, will be removed when is deallocated
    private var subscriptionTokens = [EntityObserver.SubscriptionToken]()
    
    // MARK: - Lifecycle
    
    @objc public init(distributionListEntity: DistributionListEntity) {
       
        self.distributionListID = Int(distributionListEntity.distributionListID)
        self.profilePicture = distributionListEntity.conversation.groupImage?.data
        self.displayName = distributionListEntity.name
        self.recipients = Set(distributionListEntity.conversation.members.map {
            Contact(contactEntity: $0)
        })

        super.init()
        
        // Update tracking
        subscribeForDistributionListEntityChanges(distributionListEntity: distributionListEntity)
        subscribeForConversationChanges(conversation: distributionListEntity.conversation)
    }
    
    // MARK: - Private functions
    
    private func subscribeForDistributionListEntityChanges(distributionListEntity: DistributionListEntity) {
        let token = EntityObserver.shared
            .subscribe(managedObject: distributionListEntity) { [weak self] managedObject, reason in
            
                // Checks
                guard let self else {
                    return
                }
            
                // Change handling
                switch reason {
                case .updated:
                    guard let distributionListEntity = managedObject as? DistributionListEntity else {
                        DDLogError("Wrong type, should be DistributionListEntity.")
                        return
                    }
                
                    guard distributionListID == distributionListEntity.distributionListID else {
                        DDLogError("DistributionList identity mismatch")
                        return
                    }
                    
                    return
                
                case .deleted:
                    willBeDeleted = true
                }
            }
        subscriptionTokens.append(token)
    }
    
    private func subscribeForConversationChanges(conversation: Conversation) {
        let token = EntityObserver.shared.subscribe(managedObject: conversation) { [weak self] managedObject, reason in
           
            // Checks
            guard let self else {
                return
            }

            guard let conversation = managedObject as? Conversation else {
                DDLogError("Wrong type, should be Conversation")
                return
            }
            
            guard let distributionList = conversation.distributionList,
                  distributionListID == distributionList.distributionListID else {
                DDLogError("DistributionList identity mismatch")
                return
            }
            
            // Change handling
            switch reason {
            case .updated:
                
                if profilePicture != conversation.groupImage?.data {
                    profilePicture = conversation.groupImage?.data
                }
                if displayName != conversation.displayName {
                    displayName = conversation.displayName
                }
                
                // Check has recipients composition changed
                let newRecipients = Set(conversation.members.map { Contact(contactEntity: $0) })
                
                if !recipients.contactsEqual(to: newRecipients) {
                    recipients = newRecipients
                }
                
            case .deleted:
                willBeDeleted = true
            }
        }
        subscriptionTokens.append(token)
    }
}
