//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

public class OnPremCachedConfigFetcher: OnPremConfigFetcherProtocol {
    private let trustedPublicKeys: [String]
    private let cacheURL: URL
    private let queue: DispatchQueue
    
    private var cachedConfig: OnPremConfig?
    
    public init(trustedPublicKeys: [String], cacheURL: URL) {
        self.trustedPublicKeys = trustedPublicKeys
        self.cacheURL = cacheURL
        self.queue = DispatchQueue(label: "OnPremCachedConfigFetcher")
    }
    
    public func fetch(completionHandler: @escaping (Swift.Result<OnPremConfig, Error>) -> Void) {
        
        queue.async { [weak self] in
            do {
                guard let self else {
                    completionHandler(.failure(OnPremConfigError.fetcherReleased))
                    return
                }
                
                if let cachedConfig {
                    completionHandler(.success(cachedConfig))
                    return
                }
                
                let oppfData = try String(contentsOf: cacheURL)
                if oppfData == "Unauthorized" {
                    throw OnPremConfigError.unauthorized
                }
                let verifier = OnPremConfigVerifier(trustedPublicKeys: trustedPublicKeys)
                let config = try verifier.verify(oppfData: oppfData)
                cachedConfig = config
                
                completionHandler(.success(config))
            }
            catch let err {
                completionHandler(.failure(err))
            }
        }
    }
}
