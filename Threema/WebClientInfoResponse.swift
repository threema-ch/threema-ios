//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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
    
    init(requestId: String?) {
        device = UIDevice.current.name
        os = "ios"
        osVersion = UIDevice.current.systemVersion
        appVersion = BundleUtil.mainBundle()!.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        isWork = LicenseStore.requiresLicenseKey()
        let tmpPushToken = AppGroup.userDefaults().object(forKey: kVoIPPushNotificationDeviceToken) as? Data
        if tmpPushToken != nil {
            #if DEBUG
            let server = "s"
            #else
            let server = "p"
            #endif
            pushToken = tmpPushToken!.hexEncodedString() + ";" + server + ";" + Bundle.main.bundleIdentifier! + ".voip"

        }
        configuration = WebClientInfoConfiguration.init()
        capabilities = WebClientInfoCapabilities.init()
        
        var tmpData:[AnyHashable:Any?] = ["device": device, "os": os, "osVersion": osVersion, "appVersion": appVersion, "isWork": isWork, "configuration": configuration.objectDict(), "capabilities": capabilities.objectDict()]
        if pushToken != nil {
            tmpData.updateValue(pushToken, forKey: "pushToken")
        }
        let tmpAck = requestId != nil ? WebAbstractMessageAcknowledgement.init(requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "clientInfo", requestId: nil, ack: tmpAck, args: nil, data: tmpData)
    }
}

struct WebClientInfoConfiguration {
    var voipEnabled: Bool
    var voipForceTurn: Bool
    var largeSingleEmoji: Bool
    var showInactiveIDs: Bool
    
    init() {
        
        voipEnabled = false
        if UserSettings.shared().enableThreemaCall == true {
            voipEnabled = true
        }
        
        voipForceTurn = UserSettings.shared().alwaysRelayCalls
        largeSingleEmoji = !UserSettings.shared().disableBigEmojis
        showInactiveIDs = !UserSettings.shared().hideStaleContacts
    }
    
    func objectDict() -> [String: Any] {
        return ["voipEnabled": voipEnabled, "voipForceTurn": voipForceTurn, "largeSingleEmoji": largeSingleEmoji, "showInactiveIDs": showInactiveIDs]
    }
}

struct WebClientInfoCapabilities {
    var maxGroupSize: Int
    var distributionLists: Bool
    var maxFileSize: Int
    var mdm: WebClientInfoMdmRestrictions?
    var recurrentPushes: Bool
    var imageFormat: WebClientInfoImageFormat
    
    init() {
        maxGroupSize = BundleUtil.object(forInfoDictionaryKey: "ThreemaMaxGroupMembers") as! Int
        distributionLists = false
        mdm = WebClientInfoMdmRestrictions.init()
        maxFileSize = kMaxFileSize
        recurrentPushes = true
        imageFormat = WebClientInfoImageFormat.init()
    }
    
    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["maxGroupSize": maxGroupSize, "maxFileSize": maxFileSize, "distributionLists": distributionLists, "recurrentPushes": recurrentPushes, "imageFormat": imageFormat.objectDict()]
        if mdm != nil && MDMSetup(setup: false).isManaged() {
            objectDict.updateValue(mdm!.objectDict(), forKey: "mdm")
        }
        return objectDict
    }
}

struct WebClientInfoImageFormat {
    var avatar: String
    var thumbnail: String
    
    init() {
        avatar = "image/jpeg"
        thumbnail = "image/jpeg"
    }
    
    func objectDict() -> [String: Any] {
        return ["avatar": avatar, "thumbnail": thumbnail]
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
        disableAddContact = mdmSetup.disableAddContact()
        disableCreateGroup = mdmSetup.disableCreateGroup()
        disableSaveToGallery = mdmSetup.disableSaveToGallery()
        disableExport = mdmSetup.disableExport()
        disableMessagePreview = mdmSetup.disableMessagePreview()
        disableCalls = mdmSetup.disableCalls()
        readonlyProfile = mdmSetup.readonlyProfile()
    }
    
    func objectDict() -> [String: Any] {
        return ["disableAddContact": disableAddContact, "disableCreateGroup": disableCreateGroup, "disableSaveToGallery": disableSaveToGallery, "disableExport": disableExport, "disableMessagePreview": disableMessagePreview, "disableCalls": disableCalls, "readonlyProfile": readonlyProfile]
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
