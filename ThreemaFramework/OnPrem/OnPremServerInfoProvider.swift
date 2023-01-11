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

// swiftformat:disable acronyms

import CocoaLumberjackSwift
import Foundation

class OnPremServerInfoProvider: ServerInfoProvider {
    func chatServer(ipv6: Bool, completionHandler: @escaping (ChatServerInfo?, Error?) -> Void) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    completionHandler(ChatServerInfo(
                        serverNamePrefix: "",
                        serverNameSuffix: config.chat.hostname,
                        serverPorts: config.chat.ports,
                        useServerGroups: false,
                        publicKey: config.chat.publicKey,
                        publicKeyAlt: config.chat.publicKey
                    ), nil)
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    func directoryServer(ipv6: Bool, completionHandler: @escaping (DirectoryServerInfo?, Error?) -> Void) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    completionHandler(DirectoryServerInfo(url: config.directory.url), nil)
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    func blobServer(ipv6: Bool, completionHandler: @escaping (BlobServerInfo?, Error?) -> Void) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    completionHandler(BlobServerInfo(
                        downloadURL: config.blob.downloadUrl,
                        uploadURL: config.blob.uploadUrl,
                        doneURL: config.blob.doneUrl
                    ), nil)
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    func workServer(ipv6: Bool, completionHandler: @escaping (WorkServerInfo?, Error?) -> Void) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    if let workConfig = config.work {
                        completionHandler(WorkServerInfo(url: workConfig.url), nil)
                    }
                    else {
                        completionHandler(nil, OnPremConfigError.missingWorkConfig)
                    }
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    func avatarServer(ipv6: Bool, completionHandler: @escaping (AvatarServerInfo?, Error?) -> Void) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    if let avatarConfig = config.avatar {
                        completionHandler(AvatarServerInfo(url: avatarConfig.url), nil)
                    }
                    else {
                        completionHandler(nil, OnPremConfigError.missingAvatarConfig)
                    }
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    func safeServer(ipv6: Bool, completionHandler: @escaping (SafeServerInfo?, Error?) -> Void) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    if let safeConfig = config.safe {
                        completionHandler(SafeServerInfo(url: safeConfig.url), nil)
                    }
                    else {
                        completionHandler(nil, OnPremConfigError.missingSafeConfig)
                    }
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }

    func mediatorServer(
        deviceGroupIDFirstByteHex: String,
        completionHandler: @escaping (MediatorServerInfo?, Error?) -> Void
    ) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    if let mediatorConfig = config.mediator {
                        completionHandler(MediatorServerInfo(
                            deviceGroupIDFirstByteHex: deviceGroupIDFirstByteHex,
                            url: mediatorConfig.url,
                            blob: BlobServerInfo(
                                downloadURL: mediatorConfig.blob.downloadUrl,
                                uploadURL: mediatorConfig.blob.uploadUrl,
                                doneURL: mediatorConfig.blob.doneUrl
                            )
                        ), nil)
                    }
                    else {
                        completionHandler(nil, OnPremConfigError.missingMediatorConfig)
                    }
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    func webServer(ipv6: Bool, completionHandler: @escaping (WebServerInfo?, Error?) -> Void) {
        switch prepareConfigFetcher() {
        case let .success(fetcher):
            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    if let webConfig = config.web {
                        completionHandler(WebServerInfo(
                            url: webConfig.url,
                            overrideSaltyRtcHost: webConfig.overrideSaltyRtcHost,
                            overrideSaltyRtcPort: webConfig.overrideSaltyRtcPort
                        ), nil)
                    }
                    else {
                        completionHandler(nil, OnPremConfigError.missingSafeConfig)
                    }
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    private var onPremConfigFetcher: OnPremConfigFetcher?
    
    private var lastConfigURLAuth: URL?
    
    private func prepareConfigFetcher() -> Swift.Result<OnPremConfigFetcher, Error> {
        if let onPremConfigURL = LicenseStore.shared().onPremConfigURL {
            if let configURLAuth = makeURLWithUsernamePassword(
                url: onPremConfigURL,
                username: LicenseStore.shared().licenseUsername!,
                password: LicenseStore.shared().licensePassword!
            ) {
                if onPremConfigFetcher != nil {
                    // Check if the config URL has changed in the meantime
                    if configURLAuth == lastConfigURLAuth {
                        return .success(onPremConfigFetcher!)
                    }
                }
                
                onPremConfigFetcher = OnPremConfigFetcher(
                    configURL: configURLAuth,
                    trustedPublicKeys: BundleUtil.object(forInfoDictionaryKey: "ThreemaOnPremPublicKeys") as! [String]
                )
                lastConfigURLAuth = configURLAuth
                return .success(onPremConfigFetcher!)
            }
            else {
                DDLogError("Invalid config URL \(LicenseStore.shared().onPremConfigURL!)")
                return .failure(OnPremConfigError.invalidConfigUrl)
            }
        }
        else {
            DDLogError("OnPrem configuration missing")
            return .failure(OnPremConfigError.configurationMissing)
        }
    }
    
    private func makeURLWithUsernamePassword(url: String, username: String, password: String) -> URL? {
        if let url = URL(string: url) {
            var urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            urlComp.user = username
            urlComp.password = password
            return urlComp.url
        }
        else {
            return nil
        }
    }
}
