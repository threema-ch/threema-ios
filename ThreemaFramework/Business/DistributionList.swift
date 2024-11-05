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
import ThreemaMacros

/// Business representation of a Threema distribution list
public class DistributionList: NSObject {
    
    // MARK: - Public properties

    public let distributionListID: Int
    
    @objc public private(set) dynamic var displayName: String?
    @objc public private(set) dynamic var recipients = Set<Contact>()
    @objc public private(set) dynamic lazy var profilePicture: UIImage = resolveProfilePicture()

    public var recipientsSummary: String {
        guard !recipients.isEmpty else {
            return #localize("distribution_list_no_recipient_title")
        }
        
        return ListFormatter.localizedString(byJoining: recipients.map(\.shortDisplayName))
    }
    
    public var numberOfRecipients: Int {
        recipients.count
    }
    
    public var recipientCountString: String {
        if numberOfRecipients == 1 {
            #localize("distribution_list_one_recipient_title")
        }
        else {
            String.localizedStringWithFormat(
                #localize("distribution_list_multiple_recipients_title"),
                numberOfRecipients
            )
        }
    }
    
    @objc public private(set) dynamic var willBeDeleted = false
    
    // MARK: - Private properties
    
    // Tokens for entity subscriptions, will be removed when is deallocated
    private var subscriptionTokens = [EntityObserver.SubscriptionToken]()
    
    private var distributionListImageData: Data? {
        didSet {
            updateProfilePicture()
        }
    }
    
    private let idColor: UIColor
    
    // MARK: - Lifecycle
    
    @objc public init(distributionListEntity: DistributionListEntity) {
       
        self.distributionListID = Int(distributionListEntity.distributionListID)
        self.displayName = distributionListEntity.name
        self.recipients = Set(distributionListEntity.conversation.unwrappedMembers.map {
            Contact(contactEntity: $0)
        })
        self.idColor = IDColor.forData(distributionListEntity.distributionListID.littleEndianData)

        super.init()
        
        // Subscribe distribution list entity for DB updates or deletion
        subscribeForDistributionListEntityChanges(distributionListEntity: distributionListEntity)
        
        // Subscribe conversation entity for DB updates or deletion
        subscribeForConversationChanges(conversation: distributionListEntity.conversation)
    }
    
    // MARK: - Public functions

    public func generatedProfilePicture() -> UIImage {
        ProfilePictureGenerator.generateImage(for: .distributionList, color: idColor)
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
    
    private func subscribeForConversationChanges(conversation: ConversationEntity) {
        let token = EntityObserver.shared.subscribe(managedObject: conversation) { [weak self] managedObject, reason in
           
            // Checks
            guard let self else {
                return
            }

            guard let conversation = managedObject as? ConversationEntity else {
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
                
                if distributionListImageData != conversation.groupImage?.data {
                    distributionListImageData = conversation.groupImage?.data
                }
                if displayName != conversation.displayName {
                    displayName = conversation.displayName
                }
                
                // Check if recipients composition changed
                let newRecipients = Set(conversation.unwrappedMembers.map { Contact(contactEntity: $0) })
                
                if !recipients.contactsEqual(to: newRecipients) {
                    recipients = newRecipients
                }
                
            case .deleted:
                willBeDeleted = true
            }
        }
        subscriptionTokens.append(token)
    }
    
    private func updateProfilePicture() {
        profilePicture = resolveProfilePicture()
    }
    
    private func resolveProfilePicture() -> UIImage {
        if let distributionListImageData, let image = UIImage(data: distributionListImageData) {
            return image
        }
        
        return ProfilePictureGenerator.generateImage(for: .distributionList, color: idColor)
    }
}
