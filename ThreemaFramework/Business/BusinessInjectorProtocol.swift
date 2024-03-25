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
    var runsInBackground: Bool { get }
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
    var messageRetentionManager: MessageRetentionManagerModelProtocol { get }
    var userSettings: UserSettingsProtocol { get }
    var settingsStore: any SettingsStoreProtocol { get }
    var pushSettingManager: PushSettingManagerProtocol { get }

    /// Do work with a background business injector. This runs on the thread of the caller!
    ///
    /// The closure will be called with a `BusinessInjector` initialized with a background Core Data child context. All
    /// services uses the same background Core Data child context. The closure doesn't run implicit in a Core Data
    /// perform block, make your own Core Data perform block if you work with Core Data objects.
    ///
    /// - Note: If the `BusinessInjector` already runs in the background the same one will be returned. Otherwise a new
    /// one will be created.
    ///
    /// - Parameter block: Closure called with background `BusinessInjector`
    func runInBackground<T>(_ block: @escaping (BusinessInjectorProtocol) async throws -> T) async rethrows -> T

    /// Do work with a background business injector. This runs on the thread of the caller!
    ///
    /// The closure will be called with a `BusinessInjector` initialized with a background Core Data child context. All
    /// services uses the same background Core Data child context. The closure doesn't run implicit in a Core Data
    /// perform block, make your own Core Data perform block if you work with Core Data objects.
    ///
    /// - Note: If the `BusinessInjector` already runs in the background the same one will be returned. Otherwise a new
    /// one will be created.
    ///
    /// - Parameter block: Closure called with background `BusinessInjector`
    func runInBackgroundAndWait<T>(_ block: (BusinessInjectorProtocol) throws -> T) rethrows -> T
}

protocol BusinessInternalInjectorProtocol {
    var mediatorMessageProtocol: MediatorMessageProtocolProtocol { get }
    var mediatorReflectedProcessor: MediatorReflectedProcessorProtocol { get }
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
