//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
@testable import ThreemaFramework

class SSLCAHelperMock: SSLCAHelperProtocol {
    var handleCalls = [URLAuthenticationChallenge]()
    var evaluateCalls = [(trust: SecTrust, domain: String)]()

    static func canAuthenticate(_ protectionSpace: URLProtectionSpace) -> Bool {
        true
    }

    func handle(challenge: URLAuthenticationChallenge) async throws
        -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {
        handleCalls.append(challenge)
        return (URLSession.AuthChallengeDisposition.useCredential, nil)
    }

    func evaluate(trust: SecTrust, domain: String, completionHandler: @escaping (Bool) -> Void) {
        Task {
            await completionHandler(evaluate(trust: trust, domain: domain))
        }
    }

    func evaluate(trust: SecTrust, domain: String) async -> Bool {
        evaluateCalls.append((trust, domain))
        return true
    }
}
