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

class PublicServerInfoProvider: ServerInfoProvider {
    func chatServer(ipv6: Bool, completionHandler: @escaping (ChatServerInfo?, Error?) -> Void) {
        completionHandler(ChatServerInfo(
            serverNamePrefix: chatServerNamePrefix(ipv6: ipv6),
            serverNameSuffix: chatServerNameSuffix(ipv6: ipv6),
            serverPorts: chatServerPorts(),
            useServerGroups: true,
            publicKey: chatServerPublicKey(),
            publicKeyAlt: chatServerPublicKeyAlt()
        ), nil)
    }

    private func chatServerNamePrefix(ipv6: Bool) -> String {
        var keyName = TargetManager.isBusinessApp ? "ThreemaWork" : "Threema"
        keyName += "ServerNamePrefix"
        if ipv6 {
            keyName += "v6"
        }
        guard let chatServerNamePrefix = BundleUtil.object(forThreemaFrameworkConfigurationKey: keyName) as? String
        else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: \(keyName)")
        }
        return chatServerNamePrefix
    }

    private func chatServerNameSuffix(ipv6: Bool) -> String {
        guard let chatServerNameSuffix = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaServerNameSuffix") as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaServerNameSuffix")
        }
        return chatServerNameSuffix
    }

    private func chatServerPorts() -> [Int] {
        guard let chatServerPorts = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaServerPorts") as? [Int] else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaServerPorts")
        }
        return chatServerPorts
    }

    private func chatServerPublicKey() -> Data {
        guard let chatServerPublicKey = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaServerPublicKey") as? Data else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaServerPublicKey")
        }
        return chatServerPublicKey
    }

    private func chatServerPublicKeyAlt() -> Data {
        guard let chatServerPublicKeyAlt = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaServerAltPublicKey") as? Data else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaServerAltPublicKey")
        }
        return chatServerPublicKeyAlt
    }

    func directoryServer(ipv6: Bool, completionHandler: @escaping (DirectoryServerInfo?, Error?) -> Void) {
        var keyName = "ThreemaAPIURL"
        if ipv6 {
            keyName += "v6"
        }
        if TargetManager.isBusinessApp {
            keyName += "Work"
        }
        
        guard let directoryServer = BundleUtil.object(forThreemaFrameworkConfigurationKey: keyName) as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: \(keyName)")
        }
        completionHandler(
            DirectoryServerInfo(url: directoryServer),
            nil
        )
    }

    func blobServer(ipv6: Bool, completionHandler: @escaping (BlobServerInfo?, Error?) -> Void) {
        completionHandler(BlobServerInfo(
            downloadURL: blobServerDownloadURL(ipv6: ipv6),
            uploadURL: blobServerUploadURL(ipv6: ipv6),
            doneURL: blobServerDoneURL(ipv6: ipv6)
        ), nil)
    }

    private func blobServerDownloadURL(ipv6: Bool) -> String {
        blobServerURL(threemaFrameworkConfigurationKeyPrefix: "ThreemaBlobURL", ipv6: ipv6)
    }

    private func blobServerUploadURL(ipv6: Bool) -> String {
        blobServerURL(threemaFrameworkConfigurationKeyPrefix: "ThreemaBlobUploadURL", ipv6: ipv6)
    }

    private func blobServerDoneURL(ipv6: Bool) -> String {
        blobServerURL(threemaFrameworkConfigurationKeyPrefix: "ThreemaBlobDoneURL", ipv6: ipv6)
    }

    private func blobServerURL(threemaFrameworkConfigurationKeyPrefix: String, ipv6: Bool) -> String {
        var keyName = threemaFrameworkConfigurationKeyPrefix
        if ipv6 {
            keyName += "v6"
        }
        guard let blobServerURL = BundleUtil.object(forThreemaFrameworkConfigurationKey: keyName) as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: \(keyName)")
        }
        return blobServerURL
    }

    func workServer(ipv6: Bool, completionHandler: @escaping (WorkServerInfo?, Error?) -> Void) {
        var keyName = "ThreemaWorkAPIURL"
        if ipv6 {
            keyName += "v6"
        }

        guard let workServer = BundleUtil.object(forThreemaFrameworkConfigurationKey: keyName) as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: \(keyName)")
        }
        completionHandler(
            WorkServerInfo(url: workServer),
            nil
        )
    }

    func avatarServer(ipv6: Bool, completionHandler: @escaping (AvatarServerInfo?, Error?) -> Void) {
        guard let avatarServer = BundleUtil.object(forThreemaFrameworkConfigurationKey: "ThreemaAvatarURL") as? String
        else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaAvatarURL")
        }
        completionHandler(
            AvatarServerInfo(
                url: avatarServer
            ),
            nil
        )
    }

    func safeServer(ipv6: Bool, completionHandler: @escaping (SafeServerInfo?, Error?) -> Void) {
        guard let safeServer = BundleUtil.object(forThreemaFrameworkConfigurationKey: "ThreemaSafeURL") as? String
        else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaSafeURL")
        }
        completionHandler(
            SafeServerInfo(url: safeServer),
            nil
        )
    }

    func mediatorServer(
        deviceGroupIDFirstByteHex: String,
        completionHandler: @escaping (MediatorServerInfo?, Error?) -> Void
    ) {
        guard let threemaMediatorServerURL = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaMediatorServerURL") as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaMediatorServerURL")
        }
        guard let threemaMediatorBlobURL = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaMediatorBlobURL") as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaMediatorBlobURL")
        }
        guard let threemaMediatorBlobUploadURL = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaMediatorBlobUploadURL") as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaMediatorBlobUploadURL")
        }
        guard let threemaMediatorBlobDoneURL = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaMediatorBlobDoneURL") as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaMediatorBlobDoneURL")
        }
        completionHandler(MediatorServerInfo(
            deviceGroupIDFirstByteHex: deviceGroupIDFirstByteHex,
            url: threemaMediatorServerURL,
            blob: BlobServerInfo(
                downloadURL: threemaMediatorBlobURL,
                uploadURL: threemaMediatorBlobUploadURL,
                doneURL: threemaMediatorBlobDoneURL
            )
        ), nil)
    }

    func webServer(ipv6: Bool, completionHandler: @escaping (WebServerInfo?, Error?) -> Void) {
        guard let threemaWebURL = BundleUtil.object(forThreemaFrameworkConfigurationKey: "ThreemaWebURL") as? String
        else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaWebURL")
        }
        completionHandler(WebServerInfo(
            url: threemaWebURL,
            overrideSaltyRtcHost: nil,
            overrideSaltyRtcPort: nil
        ), nil)
    }

    func rendezvousServer(completionHandler: @escaping (RendezvousServerInfo?, Error?) -> Void) {
        guard let threemaRendezvousServerURL = BundleUtil
            .object(forThreemaFrameworkConfigurationKey: "ThreemaRendezvousServerURL") as? String else {
            fatalError("[PublicServerInfoProvider] Missing configuration key: ThreemaRendezvousServerURL")
        }
        completionHandler(RendezvousServerInfo(
            url: threemaRendezvousServerURL
        ), nil)
    }

    func domains(completionHandler: @escaping ([Domain]?, Error?) -> Void) {
        completionHandler(Domain.defaultConfig, nil)
    }
    
    func mapsServer(completionHandler: @escaping (MapsServerInfo?, Error?) -> Void) {
        guard let poiNamesURL = BundleUtil.object(forThreemaFrameworkConfigurationKey: "ThreemaPOINamesURL") as? String,
              let poiAroundURL = BundleUtil
              .object(forThreemaFrameworkConfigurationKey: "ThreemaPOIAroundURL") as? String else {
            assertionFailure(
                "ThreemaPOINamesURL and ThreemaPOIAroundURL must be set in ThreemaFrameworkConfiguration.plist"
            )
            completionHandler(nil, nil)
            return
        }
        completionHandler(MapsServerInfo(
            poiNamesURL: poiNamesURL,
            poiAroundURL: poiAroundURL
        ), nil)
    }
}
