//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
@testable import Threema

class BusinessInjectorMock: BusinessInjectorProtocol {

    func runInBackground<T>(
        _ block: @escaping (ThreemaFramework.BusinessInjectorProtocol) async throws
            -> T
    ) async rethrows -> T {
        try await block(self)
    }
    
    func runInBackgroundAndWait<T>(_ block: (ThreemaFramework.BusinessInjectorProtocol) throws -> T) rethrows -> T {
        try block(self)
    }

    // MARK: BusinessInjectorProtocol

    var runsInBackground: Bool

    var contactStore: ContactStoreProtocol

    var conversationStore: ConversationStoreProtocol

    var entityManager: EntityManager

    var groupManager: GroupManagerProtocol
    
    var distributionListManager: DistributionListManagerProtocol

    var licenseStore: LicenseStore

    var messageSender: MessageSenderProtocol

    var multiDeviceManager: MultiDeviceManagerProtocol

    var myIdentityStore: MyIdentityStoreProtocol

    var unreadMessages: UnreadMessagesProtocol

    var userSettings: UserSettingsProtocol

    var settingsStore: SettingsStoreProtocol

    var serverConnector: ServerConnectorProtocol
    
    var messageRetentionManager: any MessageRetentionManagerModelProtocol
        
    var pushSettingManager: ThreemaFramework.PushSettingManagerProtocol

    var keychainHelper: KeychainHelperProtocol

    init(
        runsInBackground: Bool = false,
        contactStore: ContactStoreProtocol = ContactStoreMock(),
        conversationStore: ConversationStoreProtocol = ConversationStoreMock(),
        entityManager: EntityManager,
        groupManager: GroupManagerProtocol = GroupManagerMock(),
        distributionListManager: DistributionListManagerProtocol = DistributionListManagerMock(),
        licenseStore: LicenseStore = LicenseStore.shared(),
        messageSender: MessageSenderProtocol = MessageSenderMock(),
        multiDeviceManager: MultiDeviceManagerProtocol = MultiDeviceManagerMock(),
        myIdentityStore: MyIdentityStoreProtocol = MyIdentityStoreMock(),
        unreadMessages: UnreadMessagesProtocol = UnreadMessagesMock(),
        userSettings: UserSettingsProtocol = UserSettingsMock(),
        settingsStore: SettingsStoreProtocol = SettingsStoreMock(),
        serverConnector: ServerConnectorProtocol = ServerConnectorMock(),
        messageRetentionManager: any MessageRetentionManagerModelProtocol = MessageRetentionManagerModelMock(),
        pushSettingManager: PushSettingManagerProtocol = PushSettingManagerMock(),
        keychainHelper: KeychainHelperProtocol = KeychainHelperMock()
    ) {
        self.runsInBackground = runsInBackground
        self.contactStore = contactStore
        self.conversationStore = conversationStore
        self.entityManager = entityManager
        self.groupManager = groupManager
        self.distributionListManager = distributionListManager
        self.licenseStore = licenseStore
        self.messageSender = messageSender
        self.multiDeviceManager = multiDeviceManager
        self.myIdentityStore = myIdentityStore
        self.unreadMessages = unreadMessages
        self.userSettings = userSettings
        self.settingsStore = settingsStore
        self.serverConnector = serverConnector
        self.messageRetentionManager = messageRetentionManager
        self.pushSettingManager = pushSettingManager
        self.keychainHelper = keychainHelper
    }
}
