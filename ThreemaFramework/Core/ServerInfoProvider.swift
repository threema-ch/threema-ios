//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

@objcMembers public class ChatServerInfo: NSObject {
    public let serverNamePrefix: String
    public let serverNameSuffix: String
    public let serverPorts: [Int]
    public let useServerGroups: Bool
    public let publicKey: Data
    public let publicKeyAlt: Data
    
    init(
        serverNamePrefix: String,
        serverNameSuffix: String,
        serverPorts: [Int],
        useServerGroups: Bool,
        publicKey: Data,
        publicKeyAlt: Data
    ) {
        self.serverNamePrefix = serverNamePrefix
        self.serverNameSuffix = serverNameSuffix
        self.serverPorts = serverPorts
        self.useServerGroups = useServerGroups
        self.publicKey = publicKey
        self.publicKeyAlt = publicKeyAlt
    }
}

@objcMembers public class DirectoryServerInfo: NSObject {
    public let url: String
    
    init(url: String) {
        self.url = url
    }
}

@objcMembers public class BlobServerInfo: NSObject {
    public let downloadURL: String
    public let uploadURL: String
    public let doneURL: String
    
    init(downloadURL: String, uploadURL: String, doneURL: String) {
        self.downloadURL = downloadURL
        self.uploadURL = uploadURL
        self.doneURL = doneURL
    }
}

@objcMembers public class WorkServerInfo: NSObject {
    public let url: String
    
    init(url: String) {
        self.url = url
    }
}

@objcMembers public class AvatarServerInfo: NSObject {
    public let url: String
    
    init(url: String) {
        self.url = url
    }
}

@objcMembers public class SafeServerInfo: NSObject {
    public let url: String
    
    init(url: String) {
        self.url = url
    }
}

@objcMembers public class MediatorServerInfo: NSObject {
    public let url: String
    public let blob: BlobServerInfo
    
    init(deviceGroupIDFirstByteHex: String, url: String, blob: BlobServerInfo) {
        let prefix4 = String(deviceGroupIDFirstByteHex.prefix(1)).lowercased()
        let prefix8 = deviceGroupIDFirstByteHex.lowercased()
        
        func replacePrefixesInURL(url: String) -> String {
            url
                .replacingOccurrences(of: "{deviceGroupIdPrefix4}", with: prefix4)
                .replacingOccurrences(of: "{deviceGroupIdPrefix8}", with: prefix8)
        }
        
        self.url = replacePrefixesInURL(url: url)
        self.blob = BlobServerInfo(
            downloadURL: replacePrefixesInURL(url: blob.downloadURL),
            uploadURL: replacePrefixesInURL(url: blob.uploadURL),
            doneURL: replacePrefixesInURL(url: blob.doneURL)
        )
    }
}

@objcMembers public class WebServerInfo: NSObject {
    public let url: String
    public let overrideSaltyRtcHost: String?
    public let overrideSaltyRtcPort: Int?
    
    init(url: String, overrideSaltyRtcHost: String?, overrideSaltyRtcPort: Int?) {
        self.url = url
        self.overrideSaltyRtcHost = overrideSaltyRtcHost
        self.overrideSaltyRtcPort = overrideSaltyRtcPort
    }
}

@objcMembers public class RendezvousServerInfo: NSObject {
    public let url: String

    init(url: String) {
        self.url = url
    }
}

@objc public protocol ServerInfoProvider {
    func chatServer(ipv6: Bool, completionHandler: @escaping (ChatServerInfo?, Error?) -> Void)
    func directoryServer(ipv6: Bool, completionHandler: @escaping (DirectoryServerInfo?, Error?) -> Void)
    func blobServer(ipv6: Bool, completionHandler: @escaping (BlobServerInfo?, Error?) -> Void)
    func workServer(ipv6: Bool, completionHandler: @escaping (WorkServerInfo?, Error?) -> Void)
    func avatarServer(ipv6: Bool, completionHandler: @escaping (AvatarServerInfo?, Error?) -> Void)
    func safeServer(ipv6: Bool, completionHandler: @escaping (SafeServerInfo?, Error?) -> Void)
    func mediatorServer(
        deviceGroupIDFirstByteHex: String,
        completionHandler: @escaping (MediatorServerInfo?, Error?) -> Void
    )
    func webServer(ipv6: Bool, completionHandler: @escaping (WebServerInfo?, Error?) -> Void)
    func rendezvousServer(completionHandler: @escaping (RendezvousServerInfo?, Error?) -> Void)
}
