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
    let sfuTOken: String
    
    // MARK: - Private Properties
    
    fileprivate let expirationDate: Date
    
    fileprivate let expirationOffset = 5
    
    // MARK: - Lifecycle
    
    public init(sfuBaseURL: String, hostNameSuffixes: [String], sfuTOken: String, expiration: Int) {
        self.sfuBaseURL = sfuBaseURL
        self.hostNameSuffixes = hostNameSuffixes
        self.sfuTOken = sfuTOken
        
        self.expirationDate = Date().addingTimeInterval(TimeInterval(expiration - expirationOffset))
    }
}
