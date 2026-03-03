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

import Network

class LocalNetworkPermissionChecker {
    func checkLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        // We use a dummy service type that doesn't actually exist
        let browser = NWBrowser(for: .bonjour(type: "_privacy-check._tcp", domain: nil), using: .tcp)
        var isDenied = false
        
        browser.stateUpdateHandler = { state in
            switch state {
            case let .waiting(error), let .failed(error):
                if case let .dns(dnsError) = error, dnsError == -65570 {
                    isDenied = true
                }
            case .ready:
                isDenied = false
            default:
                break
            }
        }
        
        browser.start(queue: .main)
        
        // We give the system 0.3 to 0.5 seconds to "object" to the connection.
        // This is usually enough time for the Privacy Daemon to trigger the failure.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            browser.cancel()
            // If the 'isDenied' flag was tripped during this window, we return false.
            completion(!isDenied)
        }
    }
}
