//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

@objc class RogueDeviceMonitor: NSObject {
    private static let maxStoredEphemeralKeyHashes = 1000
    
    private var skipNextCheck: Bool
    
    @objc override init() {
        self.skipNextCheck = false
    }
    
    @objc func recordEphemeralKeyHash(_ ephemeralKeyHash: Data, postLogin: Bool) {
        var lastEphemeralKeyHashes = getStoredHashes()
        
        DDLogInfo("Record hash (post login: \(postLogin)): \(ephemeralKeyHash.base64EncodedString())")
        
        if lastEphemeralKeyHashes.isEmpty {
            // We are in a "virgin" state, i.e. don't have any hashes recorded yet.
            if postLogin {
                // We are post-login, so we can be sure "our" hash has been stored on the server,
                // but the server may still send a hash from the previous connection (before we
                // started recording), so skip the next check to prevent a false alarm.
                skipNextCheck = true
            }
            else {
                // We are pre-login, so don't record this new first hash yet, as we want to be sure
                // one of "our" hashes has actually made it to the server.
                return
            }
        }
        
        // Check if we have already recorded this hash (e.g. pre-login)
        if lastEphemeralKeyHashes.contains(ephemeralKeyHash) {
            return
        }
        
        // Prevent unbounded growth (e.g. if server does not send indications)
        if lastEphemeralKeyHashes.count >= RogueDeviceMonitor.maxStoredEphemeralKeyHashes {
            lastEphemeralKeyHashes
                .removeFirst(lastEphemeralKeyHashes.count - RogueDeviceMonitor.maxStoredEphemeralKeyHashes + 1)
        }
        
        lastEphemeralKeyHashes.append(ephemeralKeyHash)
        storeHashes(newHashes: lastEphemeralKeyHashes)
    }
    
    @objc func checkEphemeralKeyHash(_ ephemeralKeyHash: Data) {
        DDLogInfo("Check hash: \(ephemeralKeyHash.base64EncodedString())")
        
        if skipNextCheck {
            DDLogInfo("Skipping check")
            skipNextCheck = false
            return
        }
        
        var lastEphemeralKeyHashes = getStoredHashes()
        if lastEphemeralKeyHashes.isEmpty {
            // First connection, no key hashes recorded yet
            return
        }
        
        let found = lastEphemeralKeyHashes.contains(ephemeralKeyHash)
        
        if !found || AppGroup.userDefaults().bool(forKey: kShowRogueDeviceWarningFlag) {
            // Unknown ephemeral key hash - warn user (on next app start if in extension)
            AppGroup.userDefaults().set(true, forKey: kShowRogueDeviceWarningFlag)
            if AppGroup.getCurrentType() == AppGroupTypeApp {
                NotificationCenter.default.post(name: Notification.Name(kNotificationErrorRogueDevice), object: nil)
            }
        }
        else {
            if let index = lastEphemeralKeyHashes.firstIndex(of: ephemeralKeyHash), index > 0 {
                // We can now remove all older hashes
                lastEphemeralKeyHashes.removeFirst(index)
                storeHashes(newHashes: lastEphemeralKeyHashes)
            }
        }
    }
    
    private func getStoredHashes() -> [Data] {
        var lastEphemeralKeyHashes: [Data] = []
        
        if let defaultsHashes = AppGroup.userDefaults().object(forKey: kLastEphemeralKeyHashes) {
            lastEphemeralKeyHashes = defaultsHashes as! [Data]
        }
        
        DDLogInfo("Currently stored hashes: \(printHashes(hashes: lastEphemeralKeyHashes))")
        
        return lastEphemeralKeyHashes
    }
    
    private func storeHashes(newHashes: [Data]) {
        DDLogInfo("New stored hashes: \(printHashes(hashes: newHashes))")
        AppGroup.userDefaults().set(newHashes, forKey: kLastEphemeralKeyHashes)
    }
    
    private func printHashes(hashes: [Data]) -> String {
        "[" + hashes.map { hash in
            "\"" + hash.base64EncodedString() + "\""
        }.joined(separator: ",") + "]"
    }
}
