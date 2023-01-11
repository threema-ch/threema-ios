//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

public class BusinessInjector: NSObject, FrameworkInjectorProtocol {

    // MARK: BusinessInjectorProtocol

    @objc public lazy var backgroundEntityManager = EntityManager(withChildContextForBackgroundProcess: true)

    public lazy var backgroundGroupManager: GroupManagerProtocol = GroupManager(
        serverConnector,
        myIdentityStore,
        contactStore,
        TaskManager(frameworkInjector: self),
        userSettings,
        backgroundEntityManager,
        GroupPhotoSender()
    )
    
    public lazy var contactStore: ContactStoreProtocol = ContactStore.shared()
    
    public lazy var entityManager = EntityManager()

    public lazy var groupManager: GroupManagerProtocol = GroupManager(
        serverConnector,
        myIdentityStore,
        contactStore,
        TaskManager(frameworkInjector: self),
        userSettings,
        entityManager,
        GroupPhotoSender()
    )

    public lazy var licenseStore = LicenseStore.shared()

    public lazy var messageSender: MessageSenderProtocol = MessageSender(TaskManager(frameworkInjector: self))

    public lazy var multiDeviceManager: MultiDeviceManagerProtocol =
        MultiDeviceManager(serverConnector: serverConnector)

    public lazy var myIdentityStore: MyIdentityStoreProtocol = MyIdentityStore.shared()

    @objc public lazy var userSettings: UserSettingsProtocol = UserSettings.shared()

    public lazy var serverConnector: ServerConnectorProtocol = ServerConnector.shared()

    // MARK: BusinessInternalInjectorProtocol

    private var mediatorReflectedProcessorInstance: MediatorReflectedProcessorProtocol?
    private var messageProcessorInstance: MessageProcessorProtocol?
    private var fsmpInstance: ForwardSecurityMessageProcessor?
    private var fsStatusSender: ForwardSecurityStatusSender?
    
    private static var dhSessionStoreInstance: DHSessionStoreProtocol = try! SQLDHSessionStore()

    public lazy var backgroundUnreadMessages: UnreadMessagesProtocol = UnreadMessages(
        entityManager: backgroundEntityManager
    )

    lazy var mediatorMessageProtocol: MediatorMessageProtocolProtocol = MediatorMessageProtocol(
        deviceGroupKeys: self
            .serverConnector.deviceGroupKeys
    )
    
    var messageProcessor: MessageProcessorProtocol {
        if messageProcessorInstance == nil {
            messageProcessorInstance = MessageProcessor(
                serverConnector,
                entityManager: backgroundEntityManager,
                fsmp: fsmp
            )
        }
        return messageProcessorInstance!
    }
    
    var fsmp: ForwardSecurityMessageProcessor {
        if fsmpInstance == nil {
            fsmpInstance = ForwardSecurityMessageProcessor(
                dhSessionStore: dhSessionStore,
                identityStore: myIdentityStore,
                messageSender: MessageSenderAdapter()
            )
            
            fsStatusSender = ForwardSecurityStatusSender(entityManager: entityManager)
            fsmpInstance?.addListener(listener: fsStatusSender!)
        }
        return fsmpInstance!
    }
    
    public var dhSessionStore: DHSessionStoreProtocol {
        BusinessInjector.dhSessionStoreInstance
    }
    
    class MessageSenderAdapter: ForwardSecurityMessageSenderProtocol {
        func send(message: AbstractMessage) {
            MessageSender.send(message, isPersistent: true)
        }
    }
}
