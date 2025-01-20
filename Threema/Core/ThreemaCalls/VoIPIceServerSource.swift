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
import ThreemaFramework

let MIN_SPARE_VALIDITY: TimeInterval = 3600

struct TurnServerInfo {
    var turnURLs: [String]
    var turnURLsDualStack: [String]
    var turnUsername: String
    var turnPassword: String
    var expirationDate: Date
}

enum TurnServerError: Error {
    case badServerData
}

enum VoIPIceServerSource {
    private static var cachedTurnServers: TurnServerInfo?
    
    public static func prefetchIceServers() {
        obtainIceServers(dualStack: false) { _ in
            // ignored
        }
    }
    
    public static func obtainIceServers(
        dualStack: Bool,
        completion: @escaping (Swift.Result<RTCIceServer, Error>) -> Void
    ) {
        if cachedTurnServers != nil {
            let minExpiration = Date().addingTimeInterval(MIN_SPARE_VALIDITY)
            if cachedTurnServers!.expirationDate > minExpiration {
                completion(.success(makeIceServers(dualStack: dualStack, turnServerInfo: cachedTurnServers!)))
                return
            }
        }
        
        // No unexpired TURN server info in cache; must fetch
        ServerAPIConnector()
            .obtainTurnServers(with: MyIdentityStore.shared()) { (response: [AnyHashable: Any]?) in
                guard let expiration = response?["expiration"] as? TimeInterval,
                      let turnURLs = response?["turnUrls"] as? [String],
                      let turnURLsDualStack = response?["turnUrlsDualStack"] as? [String],
                      let turnUsername = response?["turnUsername"] as? String,
                      let turnPassword = response?["turnPassword"] as? String else {
                    completion(.failure(TurnServerError.badServerData))
                    return
                }
            
                let expirationDate = Date().addingTimeInterval(expiration)
                cachedTurnServers = TurnServerInfo(
                    turnURLs: turnURLs,
                    turnURLsDualStack: turnURLsDualStack,
                    turnUsername: turnUsername,
                    turnPassword: turnPassword,
                    expirationDate: expirationDate
                )
                completion(.success(makeIceServers(dualStack: dualStack, turnServerInfo: cachedTurnServers!)))
            } onError: { (e: Error?) in
                completion(.failure(e!))
            }
    }
    
    private static func makeIceServers(dualStack: Bool, turnServerInfo: TurnServerInfo) -> RTCIceServer {
        let urls = dualStack ? turnServerInfo.turnURLsDualStack : turnServerInfo.turnURLs
        return RTCIceServer(
            urlStrings: urls,
            username: turnServerInfo.turnUsername,
            credential: turnServerInfo.turnPassword,
            tlsCertPolicy: .secure
        )
    }
}
