import CocoaLumberjackSwift
import FileUtility
import Foundation
import Keychain

protocol OnPremConfigFetcherDelegate: AnyObject {
    func oppfFileUpdated()
}

final class OnPremConfigFetcher: OnPremConfigFetcherProtocol {
    private let configDownloader: OnPremConfigDownloaderProtocol
    private let configVerifier: OnPremConfigVerifierProtocol
    private let cacheURL: URL
    private weak var delegate: OnPremConfigFetcherDelegate?

    private static var currentTask: Task<OnPremConfig, any Error>? = nil
    private var cachedConfig: OnPremConfig?

    init(
        configDownloader: OnPremConfigDownloaderProtocol,
        configVerifier: OnPremConfigVerifierProtocol,
        cacheURL: URL,
        delegate: OnPremConfigFetcherDelegate
    ) {
        self.configDownloader = configDownloader
        self.configVerifier = configVerifier
        self.cacheURL = cacheURL
        self.delegate = delegate
    }
    
    func fetch(completionHandler: @escaping (Swift.Result<OnPremConfig, Error>) -> Void) {
        DDLogVerbose("[Fetch OPPF] New fetch")

        // If a task already runs we wait for the result. If no task exists we create a new one and wait on it
        //
        // Note: This is intentionally not fully race safe if the fetch task should only be run once. We landed on this
        // implementation to keep the code more readable and because multiple request to fetch the OPPF are not too
        // resource intensive. This could be fixed by protecting the access of `currentTask` either by making this class
        // an actor or using some sort of mutex or queue.
        Task {
            // The cache is never reset. Thus we can take this shortcut if the config is already cached
            if await !self.configDownloader.isRecoveryModeEnabled, let cachedConfig {
                DDLogVerbose("[Fetch OPPF] Getting from cache")
                completionHandler(.success(cachedConfig))
                return
            }

            let task: Task<OnPremConfig, any Error>
            if let currentTask = OnPremConfigFetcher.currentTask {
                DDLogVerbose("[Fetch OPPF] Load existing fetch task to wait on it")
                task = currentTask
            }
            else {
                DDLogVerbose("[Fetch OPPF] Create new fetch task")
                let newTask = Task {
                    var doFetching = true
                    while doFetching {
                        do {
                            let config = try await self.fetch()
                            doFetching = false
                            return config
                        }
                        catch OnPremConfigError.fetchRequestFailed {
                            DDLogVerbose("[Fetch OPPF] Fetch failed, retry in 10s")
                            try await Task.sleep(seconds: 10)
                        }
                        catch {
                            doFetching = false
                            DDLogError("[Fetch OPPF] Fetch failed: \(error)")
                            throw error
                        }
                    }
                }
                OnPremConfigFetcher.currentTask = newTask

                task = newTask
            }

            defer {
                OnPremConfigFetcher.currentTask = nil
            }

            do {
                let config = try await task.value
                completionHandler(.success(config))
            }
            catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    private func fetch() async throws -> OnPremConfig {
        let isRecoveryModeEnabled = await configDownloader.isRecoveryModeEnabled
        if !isRecoveryModeEnabled, let cachedConfig {
            DDLogVerbose("[Fetch OPPF] Getting from cache 2")
            return cachedConfig
        }

        DDLogVerbose("[Fetch OPPF] Fetch from server")
        let result = try await configDownloader.downloadData()

        guard let httpResponse = result.response as? HTTPURLResponse else {
            throw OnPremConfigError.fetchRequestFailed
        }

        switch httpResponse.statusCode {
        case 400:
            DDLogError("[Fetch OPPF] HTTP status code: \(httpResponse.statusCode)")
            if isRecoveryModeEnabled {
                DDLogError("[Fetch OPPF] HTTP Authorization contains user or password")
            }
            throw OnPremConfigError.fetchRequestFailed
        case 404:
            DDLogError("[Fetch OPPF] HTTP status code: \(httpResponse.statusCode)")
            if isRecoveryModeEnabled {
                DDLogError(
                    "[Fetch OPPF] The temporary fallback has not been activated via cockpit"
                )
            }
            throw OnPremConfigError.fetchRequestFailed
        case 429:
            DDLogError("[Fetch OPPF] HTTP status code: \(httpResponse.statusCode)")
            if isRecoveryModeEnabled {
                DDLogError("[Fetch OPPF] License check exceeds quota per IP per minute")
            }
            throw OnPremConfigError.fetchRequestFailed
        case 200:
            DDLogVerbose("[Fetch OPPF] Fetch was successful")
        default:
            DDLogVerbose("[Fetch OPPF] Untreated HTTP code: \(httpResponse.statusCode)")
            throw OnPremConfigError.fetchRequestFailed
        }

        guard let oppfString = String(data: result.oppfData, encoding: .utf8) else {
            throw OnPremConfigError.badInputOppfData
        }
        
        if oppfString == "Unauthorized" {
            throw OnPremConfigError.unauthorized
        }
        let config = try configVerifier.verify(oppfData: oppfString)
        cachedConfig = config

        // Caches the new OPPF file and reset cached pins
        FileUtility.shared.write(contents: result.oppfData, to: cacheURL)
        await configDownloader.enableRecoveryMode(false)

        delegate?.oppfFileUpdated()

        NotificationCenter.default.post(name: .resetSSLCAHelperCache, object: nil)

        return config
    }
}
