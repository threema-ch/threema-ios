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
        return BundleUtil.object(forInfoDictionaryKey: keyName) as! String
    }

    private func chatServerNameSuffix(ipv6: Bool) -> String {
        BundleUtil.object(forInfoDictionaryKey: "ThreemaServerNameSuffix") as! String
    }

    private func chatServerPorts() -> [Int] {
        BundleUtil.object(forInfoDictionaryKey: "ThreemaServerPorts") as! [Int]
    }

    private func chatServerPublicKey() -> Data {
        BundleUtil.object(forInfoDictionaryKey: "ThreemaServerPublicKey") as! Data
    }

    private func chatServerPublicKeyAlt() -> Data {
        BundleUtil.object(forInfoDictionaryKey: "ThreemaServerAltPublicKey") as! Data
    }

    func directoryServer(ipv6: Bool, completionHandler: @escaping (DirectoryServerInfo?, Error?) -> Void) {
        var keyName = "ThreemaAPIURL"
        if ipv6 {
            keyName += "v6"
        }
        if TargetManager.isBusinessApp {
            keyName += "Work"
        }

        completionHandler(DirectoryServerInfo(url: BundleUtil.object(forInfoDictionaryKey: keyName) as! String), nil)
    }

    func blobServer(ipv6: Bool, completionHandler: @escaping (BlobServerInfo?, Error?) -> Void) {
        completionHandler(BlobServerInfo(
            downloadURL: blobServerDownloadURL(ipv6: ipv6),
            uploadURL: blobServerUploadURL(ipv6: ipv6),
            doneURL: blobServerDoneURL(ipv6: ipv6)
        ), nil)
    }

    private func blobServerDownloadURL(ipv6: Bool) -> String {
        blobServerURL(infoKeyPrefix: "ThreemaBlobURL", ipv6: ipv6)
    }

    private func blobServerUploadURL(ipv6: Bool) -> String {
        blobServerURL(infoKeyPrefix: "ThreemaBlobUploadURL", ipv6: ipv6)
    }

    private func blobServerDoneURL(ipv6: Bool) -> String {
        blobServerURL(infoKeyPrefix: "ThreemaBlobDoneURL", ipv6: ipv6)
    }

    private func blobServerURL(infoKeyPrefix: String, ipv6: Bool) -> String {
        var keyName = infoKeyPrefix
        if ipv6 {
            keyName += "v6"
        }
        return BundleUtil.object(forInfoDictionaryKey: keyName) as! String
    }

    func workServer(ipv6: Bool, completionHandler: @escaping (WorkServerInfo?, Error?) -> Void) {
        var keyName = "ThreemaWorkAPIURL"
        if ipv6 {
            keyName += "v6"
        }

        completionHandler(WorkServerInfo(url: BundleUtil.object(forInfoDictionaryKey: keyName) as! String), nil)
    }

    func avatarServer(ipv6: Bool, completionHandler: @escaping (AvatarServerInfo?, Error?) -> Void) {
        completionHandler(
            AvatarServerInfo(url: BundleUtil.object(forInfoDictionaryKey: "ThreemaAvatarURL") as! String),
            nil
        )
    }

    func safeServer(ipv6: Bool, completionHandler: @escaping (SafeServerInfo?, Error?) -> Void) {
        completionHandler(
            SafeServerInfo(url: BundleUtil.object(forInfoDictionaryKey: "ThreemaSafeURL") as! String),
            nil
        )
    }

    func mediatorServer(
        deviceGroupIDFirstByteHex: String,
        completionHandler: @escaping (MediatorServerInfo?, Error?) -> Void
    ) {
        completionHandler(MediatorServerInfo(
            deviceGroupIDFirstByteHex: deviceGroupIDFirstByteHex,
            url: BundleUtil.object(forInfoDictionaryKey: "ThreemaMediatorServerURL") as! String,
            blob: BlobServerInfo(
                downloadURL: BundleUtil.object(forInfoDictionaryKey: "ThreemaMediatorBlobURL") as! String,
                uploadURL: BundleUtil.object(forInfoDictionaryKey: "ThreemaMediatorBlobUploadURL") as! String,
                doneURL: BundleUtil.object(forInfoDictionaryKey: "ThreemaMediatorBlobDoneURL") as! String
            )
        ), nil)
    }

    func webServer(ipv6: Bool, completionHandler: @escaping (WebServerInfo?, Error?) -> Void) {
        completionHandler(WebServerInfo(
            url: BundleUtil.object(forInfoDictionaryKey: "ThreemaWebURL") as! String,
            overrideSaltyRtcHost: nil,
            overrideSaltyRtcPort: nil
        ), nil)
    }

    func rendezvousServer(completionHandler: @escaping (RendezvousServerInfo?, Error?) -> Void) {
        completionHandler(RendezvousServerInfo(
            url: BundleUtil.object(forInfoDictionaryKey: "ThreemaRendezvousServerURL") as! String
        ), nil)
    }

    func domains(completionHandler: @escaping ([Domain]?, Error?) -> Void) {
        completionHandler(Domain.defaultConfig, nil)
    }
}
