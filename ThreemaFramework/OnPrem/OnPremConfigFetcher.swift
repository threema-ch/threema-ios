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

public class OnPremConfigFetcher {
    private let configURL: URL
    private let trustedPublicKeys: [String]
    private let queue: DispatchQueue
    
    private var cachedConfig: OnPremConfig?
    
    public init(configURL: URL, trustedPublicKeys: [String]) {
        self.configURL = configURL
        self.trustedPublicKeys = trustedPublicKeys
        self.queue = DispatchQueue(label: "OnPremConfigFetcher")
    }
    
    public func fetch(completionHandler: @escaping (Swift.Result<OnPremConfig, Error>) -> Void) {
        
        queue.async {
            do {
                if self.cachedConfig != nil {
                    completionHandler(.success(self.cachedConfig!))
                    return
                }
                
                let oppfData = try String(contentsOf: self.configURL)
                if oppfData == "Unauthorized" {
                    throw OnPremConfigError.unauthorized
                }
                let verifier = OnPremConfigVerifier(trustedPublicKeys: self.trustedPublicKeys)
                let config = try verifier.verify(oppfData: oppfData)
                self.cachedConfig = config
                
                completionHandler(.success(config))
            }
            catch let err {
                completionHandler(.failure(err))
            }
        }
    }
}
