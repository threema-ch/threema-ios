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
