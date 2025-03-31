//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import CocoaLumberjack
import Foundation
import Reachability

@objc class ReachabilityWrapper: NSObject {
    
    private let reachability = try! Reachability()
    private var lastConnectionType: Reachability.Connection
    
    override init() {
        do {
            try reachability.startNotifier()
            self.lastConnectionType = reachability.connection
        }
        catch {
            DDLogNotice("Reachability init failed due to error: \(error.localizedDescription)")
            self.lastConnectionType = .unavailable
        }
        
        super.init()
    }
    
    deinit {
        reachability.stopNotifier()
    }
    
    @objc func isReachabilityUnavailable() -> Bool {
        lastConnectionType == .unavailable
    }
    
    @objc func didLastConnectionTypeChange() -> Bool {
        let newConnectionType = reachability.connection
        
        switch newConnectionType {
        case .unavailable:
            DDLogNotice("Internet is not reachable")
        case .wifi:
            DDLogNotice("Internet is reachable via WiFi")
        case .cellular:
            DDLogNotice("Internet is reachable via cellular")
        }
        
        if newConnectionType != lastConnectionType {
            lastConnectionType = newConnectionType
            return true
        }
        
        return false
    }
}
