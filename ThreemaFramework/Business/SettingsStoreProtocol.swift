//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaProtocols

public protocol SettingsStoreProtocol {
    
    // Privacy
    var syncContacts: Bool { get set }
    var blacklist: Set<String> { get set }
    var syncExclusionList: [String] { get set }
    var blockUnknown: Bool { get set }
    var allowOutgoingDonations: Bool { get set }
    var sendReadReceipts: Bool { get set }
    var sendTypingIndicator: Bool { get set }
    var choosePOI: Bool { get set }
    var hidePrivateChats: Bool { get set }
    
    // Notifications
    var enableMasterDnd: Bool { get set }
    var masterDndWorkingDays: Set<Int> { get set }
    var masterDndStartTime: String? { get set }
    var masterDndEndTime: String? { get set }
    var notificationType: NotificationType { get set }
    var pushShowPreview: Bool { get set }
    
    // Chat
    var wallpaperStore: WallpaperStore { get }
    var useBigEmojis: Bool { get set }
    var sendMessageFeedback: Bool { get set }

    // Media
    var imageSize: String { get set }
    var videoQuality: String { get set }
    var autoSaveMedia: Bool { get set }
    
    // Calls
    var enableThreemaCall: Bool { get set }
    var alwaysRelayCalls: Bool { get set }
    var includeCallsInRecents: Bool { get set }
    var enableVideoCall: Bool { get set }
    var threemaVideoCallQualitySetting: ThreemaVideoCallQualitySetting { get set }
    var voIPSound: String { get set }
    var enableThreemaGroupCalls: Bool { get set }
	
    // Multi Device
    var isMultiDeviceRegistered: Bool { get set }

    // Advanced
    var enableIPv6: Bool { get set }
    var validationLogging: Bool { get set }
    var sentryAppDevice: String? { get set }
}

protocol SettingsStoreInternalProtocol {
    func updateSettingsStore(with syncSettings: Sync_Settings)
    func syncSettingCalls()
}
