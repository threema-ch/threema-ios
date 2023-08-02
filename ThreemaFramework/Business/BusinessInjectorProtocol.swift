//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

public protocol BusinessInjectorProtocol {
    var backgroundEntityManager: EntityManager { get }
    var backgroundGroupManager: GroupManagerProtocol { get }
    var backgroundUnreadMessages: UnreadMessagesProtocol { get }
    var contactStore: ContactStoreProtocol { get }
    var conversationStore: any ConversationStoreProtocol { get }
    var entityManager: EntityManager { get }
    var groupManager: GroupManagerProtocol { get }
    var licenseStore: LicenseStore { get }
    var messageSender: MessageSenderProtocol { get }
    var multiDeviceManager: MultiDeviceManagerProtocol { get }
    var myIdentityStore: MyIdentityStoreProtocol { get }
    var serverConnector: ServerConnectorProtocol { get }
    var unreadMessages: UnreadMessagesProtocol { get }
    var userSettings: UserSettingsProtocol { get }
    var settingsStore: any SettingsStoreProtocol { get }
}

protocol BusinessInternalInjectorProtocol {
    var mediatorMessageProtocol: MediatorMessageProtocolProtocol { get }
    var messageProcessor: MessageProcessorProtocol { get }
    var dhSessionStore: DHSessionStoreProtocol { get }
    var fsmp: ForwardSecurityMessageProcessor { get }
    var conversationStoreInternal: ConversationStoreInternalProtocol { get }
    var settingsStoreInternal: SettingsStoreInternalProtocol { get }
    var userNotificationCenterManager: UserNotificationCenterManagerProtocol { get }
    var nonceGuard: NonceGuardProtocol { get }
    var blobUploader: BlobUploaderProtocol { get }
}

typealias FrameworkInjectorProtocol = BusinessInjectorProtocol & BusinessInternalInjectorProtocol
