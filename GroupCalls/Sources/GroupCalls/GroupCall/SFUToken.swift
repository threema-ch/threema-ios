//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

public struct SFUToken: Sendable {
    // MARK: - Public Properties
    
    public var stillValid: Bool {
        DDLogNotice(
            "[GroupCall] SFUToken expiration date is \(expirationDate) and is \(expirationDate.timeIntervalSinceNow > 0 ? "still valid." : "not valid anymore.")"
        )
        
        return expirationDate.timeIntervalSinceNow > 0
    }
    
    // MARK: - Internal Properties

    let sfuBaseURL: String
    let hostNameSuffixes: [String]
    let sfuToken: String
    
    // MARK: - Private Properties
    
    fileprivate let expirationDate: Date
    
    fileprivate let expirationOffset = 5
    
    // MARK: - Lifecycle
    
    public init(sfuBaseURL: String, hostNameSuffixes: [String], sfuToken: String, expiration: Int) {
        self.sfuBaseURL = sfuBaseURL
        self.hostNameSuffixes = hostNameSuffixes
        self.sfuToken = sfuToken
        
        self.expirationDate = Date().addingTimeInterval(TimeInterval(expiration - expirationOffset))
    }
    
    public func isAllowedBaseURL(baseURL: String) -> Bool {
        guard let url = URL(string: baseURL) else {
            return false
        }
        return hasAllowedProtocol(url: url) && hasAllowedHostnameSuffix(url: url)
    }
    
    public func hasAllowedProtocol(url: URL) -> Bool {
        url.scheme == ProtocolDefines.allowedBaseURLProtocol
    }
    
    // TODO: (IOS-3880) Add test
    public func hasAllowedHostnameSuffix(url: URL) -> Bool {
        var host = ""
        
        if #available(iOS 16.0, *) {
            if let givenHost = url.host() {
                host = givenHost
            }
        }
        else {
            if let givenHost = url.host {
                host = givenHost
            }
        }
        
        if let port = url.port {
            switch port {
            case -1:
                break
            default:
                var components = URLComponents()
                components.host = host
                components.port = port
                if let componentsString = components.string {
                    host = componentsString
                }
                else {
                    DDLogError("[SFUToken] Could not create host from host and port: \(host):\(port)")
                    host = "\(host):\(port)"
                }
            }
        }
        
        return hostNameSuffixes.contains {
            host.hasSuffix($0)
        }
    }
}
