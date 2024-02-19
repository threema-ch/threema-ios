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

import Foundation
import ThreemaFramework

class UserSettingsMock: NSObject, UserSettingsProtocol {

    override init() {
        // no-op
    }

    init(blacklist: [Any]? = nil, enableIPv6: Bool = false, enableMultiDevice: Bool = false) {
        if let blacklist {
            self.blacklist = NSOrderedSet(array: blacklist)
        }
        self.enableIPv6 = enableIPv6
        self.enableMultiDevice = enableMultiDevice
    }

    var appMigratedToVersion = 0

    var wallpaper: Data!
    
    var disableBigEmojis = true
    
    var sendMessageFeedback = true
    
    var chatFontSize: Float = 0.0
    
    var unknownGroupAlertList: NSMutableArray! = NSMutableArray()
    
    var enableIPv6 = true
    
    var syncContacts = false
    
    var blockUnknown = false
    
    var enablePoi = true
    
    var allowOutgoingDonations = false
    
    var sendReadReceipts = true
    
    var sendTypingIndicator = true
    
    var includeCallsInRecents = true
    
    var enableVideoCall = true
    
    var threemaVideoCallQualitySetting: ThreemaVideoCallQualitySetting = .init(0)
    
    var enableThreemaCall = true
    
    var alwaysRelayCalls = true
    
    var enableThreemaGroupCalls = true
    
    var blacklist: NSOrderedSet! = []

    var syncExclusionList: [Any]! = [Any]()
    
    var sortOrderFirstName = true
    
    var sendProfilePicture: SendProfilePicture = .init(0)
    
    var profilePictureContactList: [Any]?

    var autoSaveMedia = false
    
    var inAppSounds = true
    
    var inAppVibrate = true
    
    var inAppPreview = true
    
    var notificationType: NSNumber! = 0
    
    var imageSize: String?
    var videoQuality: String?
    var voIPSound: String?
    var pushSound: String?
    var pushGroupSound: String?
    var pushDecrypt = false
    var pushSettings = [Any]()
    var enableMasterDnd = false
    var masterDndWorkingDays: NSOrderedSet! = []
    var masterDndStartTime: String?
    var masterDndEndTime: String?
    
    var hidePrivateChats = false

    var enableMultiDevice = false
    var allowSeveralLinkedDevices = false
    var workIdentities: NSOrderedSet!
    var profilePictureRequestList: [Any]!
    var blockCommunication = false
    var donateInteractions = false
    
    var voiceMessagesShowTimeRemaining = false
           
    var disableProximityMonitoring = false
    
    var validationLogging = false
    
    var sentryAppDevice: String?
    
    var groupCallsDeveloper = false
    
    var groupCallsDebugMessages = false
    
    var keepMessagesDays = -1
    
    var enableFSv12ForTesting = true
}
