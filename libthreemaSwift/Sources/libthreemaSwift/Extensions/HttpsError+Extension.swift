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

import CocoaLumberjackSwift
import Foundation

extension Error {
    public func asHttpsError() -> HttpsError {
        if let error = self as? URLError {
            switch error.code {
            case .timedOut:
                let msg = "[HttpsError] Timed out: \(error.description)"
                DDLogError("\(msg)")
                return .Timeout(msg)
                
            case .networkConnectionLost, .notConnectedToInternet, .internationalRoamingOff, .callIsActive,
                 .dataNotAllowed:
                let msg = "[HttpsError] Connection failed: \(error.description)"
                DDLogError("\(msg)")
                return .Timeout(msg)
                
            case .badURL, .unsupportedURL, .fileDoesNotExist:
                let msg = "[HttpsError] Bad URL: \(error.description)"
                DDLogError("\(msg)")
                return .InvalidRequest(msg)
                
            case .cancelled, .userCancelledAuthentication:
                let msg = "[HttpsError] Cancelled: \(error.description)"
                DDLogError("\(msg)")
                return .Unreachable(msg)
                
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .httpTooManyRedirects,
                 .resourceUnavailable,
                 .userAuthenticationRequired,
                 .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid:
                let msg = "[HttpsError] Cannot reach host or resource: \(error.description)"
                DDLogError("\(msg)")
                return .Unreachable(msg)
            
            case .redirectToNonExistentLocation, .badServerResponse, .zeroByteResource,
                 .cannotDecodeRawData, .cannotDecodeContentData,
                 .cannotParseResponse, .dataLengthExceedsMaximum:
                let msg = "[HttpsError] Invalid response: \(error.description)"
                DDLogError("\(msg)")
                return .InvalidResponse(msg)

            case .unknown:
                let msg = "[HttpsError] Unknown URL error: \(error.description)"
                DDLogError("\(msg)")
                return .Unclassified(msg)

            default:
                let msg = "[HttpsError] Unexpected URL error: \(error.description)"
                DDLogError("\(msg)")
                return .Unclassified(msg)
            }
        }
        
        let msg = "[HttpsError] Unexpected error: \(self)"
        DDLogError("\(msg)")
        return .Unclassified(msg)
    }
}

extension URLError {
    fileprivate var description: String {
        "\(code) LocalizedDescription=\"\(localizedDescription)\""
    }
}
