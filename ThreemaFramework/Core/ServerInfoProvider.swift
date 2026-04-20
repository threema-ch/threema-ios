import Foundation

public final class ChatServerInfo: NSObject {
    @objc public let serverNamePrefix: String
    @objc public let serverNameSuffix: String
    @objc public let serverPorts: [Int]
    @objc public let useServerGroups: Bool
    @objc public let publicKey: Data
    @objc public let publicKeyAlt: Data
    
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

public final class DirectoryServerInfo: NSObject {
    @objc public let url: String
    
    init(url: String) {
        self.url = url
    }
}

public final class BlobServerInfo: NSObject {
    public let downloadURL: String
    public let uploadURL: String
    public let doneURL: String
    
    init(downloadURL: String, uploadURL: String, doneURL: String) {
        self.downloadURL = downloadURL
        self.uploadURL = uploadURL
        self.doneURL = doneURL
    }
}

public final class WorkServerInfo: NSObject {
    @objc public let url: String
    
    init(url: String) {
        self.url = url
    }
}

public final class AvatarServerInfo: NSObject {
    @objc public let url: String
    
    init(url: String) {
        self.url = url
    }
}

public final class SafeServerInfo: NSObject {
    public let url: String
    
    init(url: String) {
        self.url = url
    }
}

public final class MediatorServerInfo: NSObject {
    @objc public let url: String
    @objc public let blob: BlobServerInfo

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

public final class WebServerInfo: NSObject {
    public let url: String
    public let overrideSaltyRtcHost: String?
    public let overrideSaltyRtcPort: Int?
    
    init(url: String, overrideSaltyRtcHost: String?, overrideSaltyRtcPort: Int?) {
        self.url = url
        self.overrideSaltyRtcHost = overrideSaltyRtcHost
        self.overrideSaltyRtcPort = overrideSaltyRtcPort
    }
}

public final class RendezvousServerInfo: NSObject {
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

public final class MapsServerInfo: NSObject {
    public let poiNamesURL: String
    public let poiAroundURL: String
    
    init(poiNamesURL: String, poiAroundURL: String) {
        self.poiNamesURL = poiNamesURL
        self.poiAroundURL = poiAroundURL
    }
}

public enum DomainSpkisAlgorithm {
    case unsupported, sha256

    static func spskisAlgorithm(string: String) -> DomainSpkisAlgorithm {
        string == "sha256" ? .sha256 : .unsupported
    }
}

public final class Domain: NSObject {
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
                    ["vGQZ8hm2h+km+q7rnJ7kF9S17BwSY0rbhwjz6nIupf0=": .sha256],
                    ["3L0bKTNfTwVUCjYqqhZXJIO03qC00bSnuxZFsb09OUo=": .sha256],
                    ["NN6Lb+2AE7CN3HWZKoWOe6mmHROOnywWoKZYWL1oHIU=": .sha256],
                    ["efJCZofFPR3oV/bBk0wmehqnhy3Vv+s9P+3sjhHem/E=": .sha256],
                    ["2Vpy8qUQCqc2+Lg6BgRO8G6e6vh7NmvVHTljfwP/Pfk=": .sha256],
                    ["KKBJHJn1PQSdNTmoAfhxqWTO61r8O8bPi/JeGtP/6gg=": .sha256],
                ],
                matchMode: .includeSubdomains,
                reportUris: ["https://3ma.ch/pinreport"]
            ),
            Domain(
                "threema.com",
                spkis: [
                    ["saKwtUPx8bCj9CW+c55nU2jb4aOpr0vBD8XMJveXq34=": .sha256],
                    ["nZWRY8rNSEqxjQDQjaunWlUL+YBOTK1xN5Bb0wMq/K0=": .sha256],
                    ["5AfgU7xFqhx5AS69cQZlAGv6JpmLm0A+Z6yBrLPOCP8=": .sha256],
                    ["GGSYKwkV3h6SRIY16Ixsh8LEKuGuhx3B4CamRde4xgY=": .sha256],
                    ["oD0JGdy32wZtoUT4n9ac3HLOgEosnx2kq+qaJnmtsQk=": .sha256],
                    ["j4n4RTr0MLfQ3gBmONIFreXDq5/Kkb2oquVTmq0n5pI=": .sha256],
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
    func mapsServer(completionHandler: @escaping (MapsServerInfo?, Error?) -> Void)
    func doRecovery() async throws
}

extension ServerInfoProvider {
    // Simplest way to get work server URL for now
    public func workServerURL() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            // IPv6 check cannot be applied here as we are not allowed to load the settings
            workServer(ipv6: true) { workServerInfo, error in
                if let workServerInfo {
                    continuation.resume(returning: workServerInfo.url)
                }
                else if let error {
                    continuation.resume(throwing: error)
                }
                else {
                    assertionFailure("This should never be reached")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
