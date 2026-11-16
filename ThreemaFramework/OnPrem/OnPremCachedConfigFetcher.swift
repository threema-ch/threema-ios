final class OnPremCachedConfigFetcher: OnPremConfigFetcherProtocol {
    private let configVerifier: OnPremConfigVerifierProtocol
    private let cacheURL: URL
    private let queue: DispatchQueue
    
    private var cachedConfig: OnPremConfig?
    
    init(configVerifier: OnPremConfigVerifierProtocol, cacheURL: URL) {
        self.configVerifier = configVerifier
        self.cacheURL = cacheURL
        self.queue = DispatchQueue(label: "ch.threema.OnPremCachedConfigFetcher")
    }
    
    func fetch(completionHandler: @escaping (Swift.Result<OnPremConfig, Error>) -> Void) {
        queue.async { [self] in
            do {
                if let cachedConfig {
                    completionHandler(.success(cachedConfig))
                    return
                }
                
                let oppfData = try String(contentsOf: cacheURL)
                if oppfData == "Unauthorized" {
                    throw OnPremConfigError.unauthorized
                }
                // An expired cached OPPF is still needed for the pinning and the remote secret to download the new
                // one. The expiration is checked for every downloaded OPPF.
                let config = try configVerifier.verify(oppfData: oppfData, checkExpiration: false)
                cachedConfig = config
                
                completionHandler(.success(config))
            }
            catch let err {
                completionHandler(.failure(err))
            }
        }
    }
}
