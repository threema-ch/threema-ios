//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

public enum DomainMatchMode: String {
    case unsupported, exact, includeSubdomains

    static func matchMode(string: String) -> DomainMatchMode {
        if string == "exact" {
            .exact
        }
        else if string == "include-subdomains" {
            .includeSubdomains
        }
        else {
            .unsupported
        }
    }
}

public enum DomainSpkisAlgorithm {
    case unsupported, sha256

    static func spskisAlgorithm(string: String) -> DomainSpkisAlgorithm {
        string == "sha256" ? .sha256 : .unsupported
    }
}

@objcMembers public final class Domain: NSObject {
    public private(set) var domain: String
    public private(set) var spkis: [[String: DomainSpkisAlgorithm]]
    public private(set) var matchMode: DomainMatchMode
    public private(set) var reportUris: [String]?

    init(
        _ domain: String,
        spkis: [[String: DomainSpkisAlgorithm]],
        matchMode: DomainMatchMode,
        reportUris: [String]? = nil
    ) {
        self.domain = domain
        self.spkis = spkis
        self.matchMode = matchMode
        self.reportUris = reportUris
    }
}

extension Domain {
    static var defaultConfig: [Domain] {
        [
            Domain(
                "threema.ch",
                spkis: [
                    ["8kTK9HP1KHIP0sn6T2AFH3Bq+qq3wn2i/OJSMjewpFw=": .sha256],
                    ["KKBJHJn1PQSdNTmoAfhxqWTO61r8O8bPi/JeGtP/6gg=": .sha256],
                    ["h2gHawxPZyMCiZSkJN0dQ4RsDxowVuTmuiNQyjeU+Sk=": .sha256],
                    ["HXqz8rMr6nBDdUX3CdyIwln8ym3qFUBwv4QGyMN2uEg=": .sha256],
                    ["2Vpy8qUQCqc2+Lg6BgRO8G6e6vh7NmvVHTljfwP/Pfk=": .sha256],
                    ["vGQZ8hm2h+km+q7rnJ7kF9S17BwSY0rbhwjz6nIupf0=": .sha256],
                    ["jsQHAHKQ2oOf3rvMn9GJVIKslkhLpODGOMPSxgLeIyo=": .sha256],
                ],
                matchMode: .includeSubdomains,
                reportUris: ["https://3ma.ch/pinreport"]
            ),
            Domain(
                "sfu.threema.ch",
                spkis: [
                    ["useMPV2qPBEgxVucMPuqexG27L64zFAksHh9BehZpY0=": .sha256],
                    ["88JttF0tDWrGT6g8H9uEZ0T8xosvZtZwWlsZuD4NvHA=": .sha256],
                    ["F82gDLif130AsVx454ZsMxPGl9EpzB5LqY39CzVKWDQ=": .sha256],
                    ["Jo4Re5X+mksn/Ankgrnov07caZwkkT8NezJMQf1i8cI=": .sha256],
                ],
                matchMode: .includeSubdomains,
                reportUris: ["https://3ma.ch/pinreport"]
            ),
            
        ]
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
    func domains(completionHandler: @escaping ([Domain]?, Error?) -> Void)
}
