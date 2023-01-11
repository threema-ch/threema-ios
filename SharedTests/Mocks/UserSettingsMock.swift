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

    init(blacklist: [Any]) {
        self.blacklist = NSOrderedSet(array: blacklist)
    }

    var appMigratedToVersion = 0

    func checkWallpaper() {
        // no-op
    }
    
    var wallpaper: UIImage!
    
    var useDynamicFontSize = true
    
    var showReceivedTimestamps = true
    
    var returnToSend = true
    
    var disableBigEmojis = true
    
    var chatFontSize: Float = 0.0
    
    var unknownGroupAlertList: NSMutableArray! = NSMutableArray()
    
    var enableIPv6 = true
    
    var syncContacts = false
    
    var blockUnknown = false
    
    var sendReadReceipts = true
    
    var sendTypingIndicator = true
    
    var enableThreemaCall = true
    
    var alwaysRelayCalls = true
    
    var blacklist: NSOrderedSet! = []

    var syncExclusionList: [Any]! = [Any]()
    
    var sortOrderFirstName = true
    
    var sendProfilePicture: SendProfilePicture = .init(0)
    
    var profilePictureContactList: [Any]?

    var autoSaveMedia = false
    
    var imageSize: String?
    var videoQuality: String?
    var voIPSound: String?
    var pushSound: String?
    var pushGroupSound: String?
    var pushDecrypt = false
    var pushShowNickname = false
    var pushSettingsList: NSOrderedSet! = []
    
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
}
