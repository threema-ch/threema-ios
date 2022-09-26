//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@objc public class BlobURL: NSObject {
    enum BlobOrigin {
        case publicBlob
        case localBlob
    }
    
    private let serverConnector: ServerConnectorProtocol
    private let userSettings: UserSettingsProtocol
    private let serverInfoProvider: ServerInfoProvider
    private let origin: BlobOrigin
    private let queue: DispatchQueue
    
    @objc public init(
        serverConnector: ServerConnectorProtocol,
        userSettings: UserSettingsProtocol,
        serverInfoProvider: ServerInfoProvider,
        localOrigin: Bool = false,
        queue: DispatchQueue?
    ) {
        self.serverConnector = serverConnector
        self.userSettings = userSettings
        self.serverInfoProvider = serverInfoProvider
        self.origin = localOrigin ? .localBlob : .publicBlob
        self.queue = queue ?? DispatchQueue.main
    }
    
    @objc public convenience init(
        serverConnector: ServerConnectorProtocol,
        userSettings: UserSettingsProtocol,
        localOrigin: Bool,
        queue: DispatchQueue?
    ) {
        self.init(
            serverConnector: serverConnector,
            userSettings: userSettings,
            serverInfoProvider: ServerInfoProviderFactory.makeServerInfoProvider(),
            localOrigin: localOrigin,
            queue: queue
        )
    }
    
    @objc public convenience init(
        serverConnector: ServerConnectorProtocol,
        userSettings: UserSettingsProtocol,
        localOrigin: Bool
    ) {
        self.init(
            serverConnector: serverConnector,
            userSettings: userSettings,
            serverInfoProvider: ServerInfoProviderFactory.makeServerInfoProvider(),
            localOrigin: localOrigin,
            queue: DispatchQueue.main
        )
    }
    
    @objc public convenience init(serverConnector: ServerConnectorProtocol, userSettings: UserSettingsProtocol) {
        self.init(
            serverConnector: serverConnector,
            userSettings: userSettings,
            serverInfoProvider: ServerInfoProviderFactory.makeServerInfoProvider(),
            localOrigin: false,
            queue: DispatchQueue.main
        )
    }
    
    @objc public func download(blobID: Data, completionHandler: @escaping (URL?, Error?) -> Void) {
        genericBlobURL(blobID: blobID, extractURL: { blobServerInfo -> String in
            blobServerInfo.downloadURL
        }, completionHandler: completionHandler)
    }
    
    @objc public func upload(completionHandler: @escaping (URL?, String?, Error?) -> Void) {
        genericBlobURL(blobID: nil) { blobServerInfo -> String in
            blobServerInfo.uploadURL
        } completionHandler: { url, error in
            AuthTokenManager.shared().obtainToken { authToken, err in
                self.queue.async {
                    if error != nil {
                        completionHandler(nil, nil, err)
                    }
                    else {
                        var authorization: String?
                        if authToken != nil {
                            authorization = "Token " + authToken!
                        }
                        completionHandler(url, authorization, nil)
                    }
                }
            }
        }
    }
    
    @objc public func done(blobID: Data, completionHandler: @escaping (URL?, Error?) -> Void) {
        genericBlobURL(blobID: blobID, extractURL: { blobServerInfo -> String in
            blobServerInfo.doneURL
        }, completionHandler: completionHandler)
    }
    
    private func genericBlobURL(
        blobID: Data?,
        extractURL: @escaping (BlobServerInfo) -> String,
        completionHandler: @escaping (URL?, Error?) -> Void
    ) {
        if let deviceGroupPathKey = serverConnector.deviceGroupPathKey,
           let deviceID = serverConnector.deviceID,
           let deviceGroupID = NaClCrypto.shared()?.derivePublicKey(fromSecretKey: deviceGroupPathKey) {
            
            serverInfoProvider.mediatorServer { mediatorServerInfo, err in
                if mediatorServerInfo == nil {
                    completionHandler(nil, err)
                    return
                }
                
                let url = self.substituteBlobID(
                    url: self.substituteDeviceID(
                        url: self.substituteOrigin(url: extractURL(mediatorServerInfo!.blob)),
                        deviceID: deviceID,
                        deviceGroupID: deviceGroupID
                    ),
                    blobID: blobID
                )
                self.queue.async {
                    completionHandler(url, nil)
                }
            }
        }
        else {
            serverInfoProvider.blobServer(ipv6: userSettings.enableIPv6) { blobServerInfo, err in
                if blobServerInfo == nil {
                    completionHandler(nil, err)
                    return
                }
                
                let url = self.substituteBlobID(url: extractURL(blobServerInfo!), blobID: blobID)
                self.queue.async {
                    completionHandler(url, nil)
                }
            }
        }
    }
    
    private func getBlobIDHex(_ blobID: Data) -> (blobIDHex: String, blobFirstByteHex: String) {
        let blobIDHex: String = blobID.hexString
        let blobFirstByteHex = String(blobIDHex[...blobIDHex.index(blobIDHex.startIndex, offsetBy: 1)])
        
        return (blobIDHex, blobFirstByteHex)
    }
    
    private func substituteBlobID(url: String, blobID: Data?) -> URL {
        if let blobID = blobID {
            let idHex = getBlobIDHex(blobID)
            return URL(
                string: url.replacingOccurrences(of: "{blobIdPrefix}", with: idHex.blobFirstByteHex)
                    .replacingOccurrences(of: "{blobId}", with: idHex.blobIDHex)
            )!
        }
        else {
            return URL(string: url)!
        }
    }
    
    private func substituteDeviceID(url: String, deviceID: Data, deviceGroupID: Data) -> String {
        url.replacingOccurrences(of: "{deviceId}", with: deviceID.hexString)
            .replacingOccurrences(of: "{deviceGroupId}", with: deviceGroupID.hexString)
    }
    
    private func substituteOrigin(url: String) -> String {
        serverConnector.isMultiDeviceActivated ? url.replacingOccurrences(of: "{origin}", with: originString()) : url
    }
    
    private func originString() -> String {
        origin == .localBlob ? "local" : "public"
    }
}
