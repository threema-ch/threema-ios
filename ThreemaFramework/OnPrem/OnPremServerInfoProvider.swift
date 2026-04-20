// swiftformat:disable acronyms

import CocoaLumberjackSwift
import FileUtility
import Foundation

final class OnPremServerInfoProvider: ServerInfoProvider {
    private let configDownloader: OnPremConfigDownloaderProtocol
    private let configVerifier: OnPremConfigVerifierProtocol
    private let licenseStore: LicenseStore

    init(
        configDownloader: OnPremConfigDownloaderProtocol = OnPremConfigDownloader(),
        configVerifier: OnPremConfigVerifierProtocol = OnPremConfigVerifier(
            trustedPublicKeys: BundleUtil
                .object(forThreemaFrameworkConfigurationKey: "ThreemaOnPremPublicKeys") as? [String]
        ),
        licenseStore: LicenseStore = LicenseStore.shared()
    ) {
        self.configDownloader = configDownloader
        self.configVerifier = configVerifier
        self.licenseStore = licenseStore
    }

    func chatServer(ipv6: Bool, completionHandler: @escaping (ChatServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
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
    }

    func directoryServer(ipv6: Bool, completionHandler: @escaping (DirectoryServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
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
    }

    func blobServer(ipv6: Bool, completionHandler: @escaping (BlobServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
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
    }

    func workServer(ipv6: Bool, completionHandler: @escaping (WorkServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
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
    }

    func avatarServer(ipv6: Bool, completionHandler: @escaping (AvatarServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
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
    }

    func safeServer(ipv6: Bool, completionHandler: @escaping (SafeServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
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
    }

    func mediatorServer(
        deviceGroupIDFirstByteHex: String,
        completionHandler: @escaping (MediatorServerInfo?, Error?) -> Void
    ) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
            case let .success(fetcher):
                fetcher.fetch { result in
                    switch result {
                    case let .success(config):
                        if let mediatorConfig = config.mediator {
                            let params = "?deviceId={deviceId}&deviceGroupId={deviceGroupId}&scope={origin}"
                            completionHandler(MediatorServerInfo(
                                deviceGroupIDFirstByteHex: deviceGroupIDFirstByteHex,
                                url: mediatorConfig.url,
                                blob: BlobServerInfo(
                                    downloadURL: mediatorConfig.blob.downloadUrl + params,
                                    uploadURL: mediatorConfig.blob.uploadUrl + params,
                                    doneURL: mediatorConfig.blob.doneUrl + params
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
    }

    func webServer(ipv6: Bool, completionHandler: @escaping (WebServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
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
                            completionHandler(nil, OnPremConfigError.missingWebServerInfoConfig)
                        }
                    case let .failure(err):
                        completionHandler(nil, err)
                    }
                }
            case let .failure(err):
                completionHandler(nil, err)
            }
        }
    }
    
    func rendezvousServer(completionHandler: @escaping (RendezvousServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
            case let .success(fetcher):
                fetcher.fetch { result in
                    switch result {
                    case let .success(config):
                        if let rendezvousConfig = config.rendezvous {
                            completionHandler(RendezvousServerInfo(
                                url: rendezvousConfig.url
                            ), nil)
                        }
                        else {
                            completionHandler(nil, OnPremConfigError.missingRendezvousConfig)
                        }
                    case let .failure(err):
                        completionHandler(nil, err)
                    }
                }
            case let .failure(err):
                completionHandler(nil, err)
            }
        }
    }

    func domains(completionHandler: @escaping ([Domain]?, Error?) -> Void) {
        switch prepareCachedConfigFetcher() {
        case let .success(fetcher):
            guard let fetcher else {
                // No cached OPPF file found, but default Threema domains must always be included
                completionHandler(Domain.defaultConfig, nil)
                return
            }

            fetcher.fetch { result in
                switch result {
                case let .success(config):
                    var defaultConfig = Domain.defaultConfig
                    if let domainsConfig = config.domains {
                        defaultConfig.append(
                            contentsOf: domainsConfig.rules.map {
                                Domain(
                                    $0.fqdn,
                                    spkis: $0.spkis
                                        .map {
                                            [$0.value: DomainSpkisAlgorithm.spskisAlgorithm(string: $0.algorithm)]
                                        },
                                    matchMode: DomainMatchMode.matchMode(string: $0.matchMode)
                                )
                            }
                        )

                        completionHandler(defaultConfig, nil)
                    }
                    else {
                        // Cert pinning is optional for OnPrem, but default Threema domains must always included
                        completionHandler(defaultConfig, nil)
                    }
                case let .failure(err):
                    completionHandler(nil, err)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }
    
    func mapsServer(completionHandler: @escaping (MapsServerInfo?, Error?) -> Void) {
        prepareConfigFetcher { configFetcher in
            switch configFetcher {
            case let .success(fetcher):
                fetcher.fetch { result in
                    self.handleMapsServerResult(result, completionHandler: completionHandler)
                }
            case let .failure(err):
                completionHandler(nil, err)
            }
        }
    }
    
    private func handleMapsServerResult(
        _ result: Swift.Result<OnPremConfig, Error>,
        completionHandler: @escaping (MapsServerInfo?, Error?) -> Void
    ) {
        switch result {
        case let .success(config):
            if let mapsConfig = config.maps {
                completionHandler(MapsServerInfo(
                    poiNamesURL: mapsConfig.poiNamesURL,
                    poiAroundURL: mapsConfig.poiAroundURL
                ), nil)
            }
            else {
                PublicServerInfoProvider().mapsServer { mapsServerInfo, _ in
                    completionHandler(mapsServerInfo, nil)
                }
            }
        case let .failure(err):
            completionHandler(nil, err)
        }
    }

    /// Fetch OPPF in the recovery mode.
    func doRecovery() async throws {
        await configDownloader.enableRecoveryMode(true)

        try await withCheckedThrowingContinuation { continuation in
            prepareConfigFetcher { configFetcher in
                switch configFetcher {
                case let .success(fetcher):
                    fetcher.fetch { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case let .failure(error):
                            continuation.resume(throwing: error)
                        }
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Preparing config fetcher

    private let cachedConfigFetcherQueue =
        DispatchQueue(label: "ch.threema.OnPremServerInfoProvider.cachedConfigFetcherQueue")

    private var onPremCachedConfigFetcher: OnPremCachedConfigFetcher?
    private var onPremConfigFetcher: OnPremConfigFetcher?

    private let cachedConfigURL = FileUtility.shared.appDataDirectory(
        appGroupID: AppGroup.groupID()
    )!.appendingPathComponent("config.oppf")

    /// Preparing cached config fetcher only! This is useful to fetch domains to prevent deadlock,
    /// because the domains will be loaded within the Task to download the OPPF file.
    ///
    /// - Returns: the config fetcher or an error
    private func prepareCachedConfigFetcher() -> Swift.Result<OnPremConfigFetcherProtocol?, Error> {
        guard FileUtility.shared.fileExists(atPath: cachedConfigURL.path) else {
            DDLogWarn(
                "OnPrem configuration url not accessible and no cached config found"
            )
            return .success(nil)
        }

        let cachedConfigFetcher: OnPremConfigFetcherProtocol = cachedConfigFetcherQueue.sync {
            if let onPremCachedConfigFetcher {
                return onPremCachedConfigFetcher
            }

            onPremCachedConfigFetcher = OnPremCachedConfigFetcher(
                configVerifier: configVerifier,
                cacheURL: cachedConfigURL
            )

            return onPremCachedConfigFetcher!
        }

        return .success(cachedConfigFetcher)
    }

    /// Preparing cached or normal config fetcher. If the license set and OnPrem server known or the recovery mode is
    /// enabled,
    /// the OPPF file will be downloaded and the cached OPPF file updated.
    ///
    /// - Parameter completionHandler: Returns the config fetcher or an error
    private func prepareConfigFetcher(
        completionHandler: @escaping (Swift.Result<OnPremConfigFetcherProtocol, Error>) -> Void
    ) {
        Task {
            guard await configDownloader.isRecoveryModeEnabled || licenseStore.onPremConfigURL != nil else {

                // This is happens when the RS is fetched, then we return the config of the cached OPPF
                guard FileUtility.shared.fileExists(atPath: cachedConfigURL.path) else {
                    DDLogError(
                        "OnPrem configuration url not accessible and no cached config found"
                    )
                    completionHandler(.failure(OnPremConfigError.missingConfigurationURL))
                    return
                }

                if let onPremCachedConfigFetcher {
                    completionHandler(.success(onPremCachedConfigFetcher))
                    return
                }

                onPremCachedConfigFetcher = OnPremCachedConfigFetcher(
                    configVerifier: configVerifier,
                    cacheURL: cachedConfigURL
                )

                completionHandler(.success(onPremCachedConfigFetcher!))
                return
            }

            if let onPremConfigFetcher {
                completionHandler(.success(onPremConfigFetcher))
                return
            }

            onPremConfigFetcher = OnPremConfigFetcher(
                configDownloader: configDownloader,
                configVerifier: configVerifier,
                cacheURL: cachedConfigURL,
                delegate: self
            )

            completionHandler(.success(onPremConfigFetcher!))
        }
    }
}

protocol OnPremConfigFetcherProtocol {
    func fetch(completionHandler: @escaping (Result<OnPremConfig, Error>) -> Void)
}

// MARK: - OnPremServerInfoProvider + OnPremConfigFetcherDelegate

extension OnPremServerInfoProvider: OnPremConfigFetcherDelegate {
    func oppfFileUpdated() {
        cachedConfigFetcherQueue.sync {
            onPremCachedConfigFetcher = nil
        }
    }
}
