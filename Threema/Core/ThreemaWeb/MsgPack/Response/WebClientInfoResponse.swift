//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

class WebClientInfoResponse: WebAbstractMessage {
    
    let device: String
    let os: String
    let osVersion: String
    let appVersion: String
    let isWork: Bool
    var pushToken: String?
    let configuration: WebClientInfoConfiguration
    let capabilities: WebClientInfoCapabilities
    
    init(requestID: String?) {
        self.device = UIDevice.current.name
        self.os = "ios"
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = AppInfo.appVersion.version ?? "-"
        self.isWork = TargetManager.isBusinessApp
        let tmpPushToken = AppGroup.userDefaults().object(forKey: kPushNotificationDeviceToken) as? Data
        if tmpPushToken != nil {
            #if DEBUG
                let server = "s"
            #else
                let server = "p"
            #endif
            self.pushToken = tmpPushToken!.hexString + ";" + server + ";" + Bundle.main.bundleIdentifier!
        }
        self.configuration = WebClientInfoConfiguration()
        self.capabilities = WebClientInfoCapabilities()
        
        var tmpData: [AnyHashable: Any?] = [
            "device": device,
            "os": os,
            "osVersion": osVersion,
            "appVersion": appVersion,
            "isWork": isWork,
            "configuration": configuration.objectDict(),
            "capabilities": capabilities.objectDict(),
        ]
        if pushToken != nil {
            tmpData.updateValue(pushToken, forKey: "pushToken")
        }
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "clientInfo",
            requestID: nil,
            ack: tmpAck,
            args: nil,
            data: tmpData
        )
    }
}

struct WebClientInfoConfiguration {
    var voipEnabled: Bool
    var voipForceTurn: Bool
    var largeSingleEmoji: Bool
    var showInactiveIDs: Bool
    
    init() {
        
        self.voipEnabled = false
        if UserSettings.shared().enableThreemaCall == true {
            self.voipEnabled = true
        }
        
        self.voipForceTurn = UserSettings.shared().alwaysRelayCalls
        self.largeSingleEmoji = !UserSettings.shared().disableBigEmojis
        self.showInactiveIDs = !UserSettings.shared().hideStaleContacts
    }
    
    func objectDict() -> [String: Any] {
        [
            "voipEnabled": voipEnabled,
            "voipForceTurn": voipForceTurn,
            "largeSingleEmoji": largeSingleEmoji,
            "showInactiveIDs": showInactiveIDs,
        ]
    }
}

struct WebClientInfoCapabilities {
    var maxGroupSize = BundleUtil.object(forInfoDictionaryKey: "ThreemaMaxGroupMembers") as! Int
    var maxFileSize: Int = kMaxFileSize
    var distributionLists = false
    var recurrentPushes = true
    var imageFormat = WebClientInfoImageFormat()
    var quotesV2Support = true
    var groupReactions = true
    var emojiReactions = true
    
    var mdm = WebClientInfoMdmRestrictions()
    
    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = [
            "maxGroupSize": maxGroupSize,
            "maxFileSize": maxFileSize,
            "distributionLists": distributionLists,
            "recurrentPushes": recurrentPushes,
            "imageFormat": imageFormat.objectDict(),
            "quotesV2": quotesV2Support,
            "groupReactions": groupReactions,
            "emojiReactions": emojiReactions,
        ]
        
        if TargetManager.isBusinessApp {
            objectDict.updateValue(mdm.objectDict(), forKey: "mdm")
        }
        
        return objectDict
    }
}

struct WebClientInfoImageFormat {
    var avatar: String
    var thumbnail: String
    
    init() {
        self.avatar = "image/jpeg"
        self.thumbnail = "image/jpeg"
    }
    
    func objectDict() -> [String: Any] {
        ["avatar": avatar, "thumbnail": thumbnail]
    }
}

struct WebClientInfoMdmRestrictions {
    var disableAddContact: Bool
    var disableCreateGroup: Bool
    var disableSaveToGallery: Bool
    var disableExport: Bool
    var disableMessagePreview: Bool
    var disableCalls: Bool
    var readonlyProfile: Bool
    
    init() {
        let mdmSetup = MDMSetup(setup: false)!
        self.disableAddContact = mdmSetup.disableAddContact()
        self.disableCreateGroup = mdmSetup.disableCreateGroup()
        self.disableSaveToGallery = mdmSetup.disableSaveToGallery()
        self.disableExport = mdmSetup.disableExport()
        self.disableMessagePreview = mdmSetup.disableMessagePreview()
        self.disableCalls = mdmSetup.disableCalls()
        self.readonlyProfile = mdmSetup.readonlyProfile()
    }
    
    func objectDict() -> [String: Any] {
        [
            "disableAddContact": disableAddContact,
            "disableCreateGroup": disableCreateGroup,
            "disableSaveToGallery": disableSaveToGallery,
            "disableExport": disableExport,
            "disableMessagePreview": disableMessagePreview,
            "disableCalls": disableCalls,
            "readonlyProfile": readonlyProfile,
        ]
    }
}
