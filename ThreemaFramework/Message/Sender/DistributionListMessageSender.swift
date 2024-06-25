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
import CoreData
import CoreLocation
import Foundation
import PromiseKit
import ThreemaEssentials

/// Handles sending messages of various types to distribution list recipients
public class DistributionListMessageSender {
    
    private let businessInjector: BusinessInjectorProtocol
    private let entityManager: EntityManager
    
    public init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
        self.entityManager = businessInjector.entityManager
    }
    
    public convenience init() {
        self.init(businessInjector: BusinessInjector())
    }
    
    // MARK: - Text
    
    public func sendTextMessage(
        text: String,
        in distributionList: DistributionListEntity,
        quickReply: Bool,
        requestID: String?,
        completion: ((BaseMessage?) -> Void)?
    ) {

        guard let conversation = distributionList.conversation else {
            return
        }
        safeTextMessage(text: text, to: conversation)

        for member in conversation.members {
            if let memberConversation = entityManager.conversation(for: member.identity, createIfNotExisting: true) {
                
                businessInjector.messageSender.sendTextMessage(
                    containing: text,
                    in: memberConversation,
                    sendProfilePicture: !quickReply
                )
            }
        }
    }
    
    public func safeTextMessage(text: String?, to distributionListConversation: Conversation) {
        entityManager.performSyncBlockAndSafe {
            guard let message = self.entityManager.entityCreator.textMessage(
                for: distributionListConversation,
                setLastUpdate: true
            ) else {
                return
            }
            
            message.text = text
            message.delivered = NSNumber(booleanLiteral: true)
        }
    }
    
    // MARK: -  Blob

    public func sendBlobMessage(
        for item: URLSenderItem,
        in distributionListConversationObjectID: NSManagedObjectID,
        correlationID: String?,
        webRequestID: String?
    ) async throws {
        let conversation = try await entityManager.performSave {
            guard let conversation = self.entityManager.entityFetcher.existingObject(
                with: distributionListConversationObjectID
            ) as? Conversation else {
                throw MessageSenderError.unableToLoadConversation
            }
            return conversation
        }
        
        safeBlobMessage(for: item, to: conversation, correlationID: correlationID, webRequestID: webRequestID)
        
        for member in conversation.members {
            if let memberConversation = entityManager.conversation(for: member.identity, createIfNotExisting: true) {
                
                try await businessInjector.messageSender.sendBlobMessage(
                    for: item,
                    in: memberConversation.objectID,
                    correlationID: correlationID,
                    webRequestID: webRequestID
                )
            }
        }
    }
    
    public func safeBlobMessage(
        for item: URLSenderItem,
        to distributionListConversation: Conversation,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) {
        Task {
            try await entityManager.performSave {
                let fileMessageEntity = try self.entityManager.entityCreator.createFileMessageEntity(
                    for: item,
                    in: distributionListConversation,
                    with: .local,
                    correlationID: correlationID,
                    webRequestID: webRequestID
                )
                
                fileMessageEntity.progress = nil
                fileMessageEntity.blobError = false
                // This will be resolved with reflection for MD
                fileMessageEntity.blobIdentifier = Data(count: 1)
                fileMessageEntity.delivered = NSNumber(booleanLiteral: true)
            }
        }
    }
    
    // MARK: - Location

    public func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in distributionList: DistributionListEntity
    ) {
        guard let conversation = distributionList.conversation else {
            return
        }
        safeLocationMessage(
            coordinates: coordinates,
            accuracy: accuracy,
            poiName: poiName,
            poiAddress: poiAddress,
            to: conversation
        )

        for member in conversation.members {
            if let memberConversation = entityManager.conversation(for: member.identity, createIfNotExisting: true) {
                
                businessInjector.messageSender.sendLocationMessage(
                    coordinates: coordinates,
                    accuracy: accuracy,
                    poiName: poiName,
                    poiAddress: poiAddress,
                    in: memberConversation
                )
            }
        }
    }
    
    public func safeLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        to distributionListConversation: Conversation
    ) {
        entityManager.performSyncBlockAndSafe {
            guard let message = self.entityManager.entityCreator.locationMessage(
                for: distributionListConversation,
                setLastUpdate: true
            ) else {
                return
            }

            message.latitude = NSNumber(floatLiteral: coordinates.latitude)
            message.longitude = NSNumber(floatLiteral: coordinates.longitude)
            message.accuracy = NSNumber(floatLiteral: accuracy)
            message.poiName = poiName
            message.poiAddress = poiAddress
            
            message.delivered = NSNumber(booleanLiteral: true)
        }
    }
}
