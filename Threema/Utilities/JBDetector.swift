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

import CocoaLumberjackSwift
import Foundation

@objc class JBDetector: NSObject {
    
    enum JBError: Error {
        case fileAtPathExists
        case writeFileSucceeded
        case appInstalled
    }
    
    /// Note: These paths are by no means a complete list
    private lazy var pathsToCheck: [String] =
        [
            "/usr/sbin/frida-server",
            "/etc/apt/sources.list.d/electra.list",
            "/etc/apt/sources.list.d/sileo.sources",
            "/.bootstrapped_electra",
            "/usr/lib/libjailbreak.dylib",
            "/jb/lzma",
            "/.cydia_no_stash",
            "/.installed_unc0ver",
            "/jb/offsets.plist",
            "/usr/share/jailbreak/injectme.plist",
            "/etc/apt/undecimus/undecimus.list",
            "/var/lib/dpkg/info/mobilesubstrate.md5sums",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/jb/jailbreakd.plist",
            "/jb/amfid_payload.dylib",
            "/jb/libjailbreak.dylib",
            "/usr/libexec/cydia/firmware.sh",
            "/var/lib/cydia",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/Users/",
            "/var/log/apt",
            "/Applications/Cydia.app",
            "/private/var/stash",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/cache/apt/",
            "/private/var/log/syslog",
            "/private/var/tmp/cydia.log",
            "/Applications/Icy.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/blackra1n.app",
            "/Applications/SBSettings.app",
            "/Applications/FakeCarrier.app",
            "/Applications/WinterBoard.app",
            "/Applications/IntelliScreen.app",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/Library/MobileSubstrate/CydiaSubstrate.dylib",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/Applications/Cydia.app",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
        ]
    
    /// Basic, not that sophisticated, detector if the device the app is running on might be jailbroken.
    @objc func detectJB() -> Bool {
        do {
            // Check well known paths
            try checkPaths()
            
            // Try to write file in restricted directory
            try checkWrite()
            
            // Try to open commonly installed apps
            try openApp()

            // If no check did throw, we assume the device is not jailbroken
            return false
        }
        catch {
            DDLogError("Jailbreak detected: \(error.localizedDescription).")
            return true
        }
    }
    
    private func checkPaths() throws {
        for path in pathsToCheck {
            guard !FileManager.default.fileExists(atPath: path) else {
                throw JBError.fileAtPathExists
            }
        }
    }
    
    /// Try to write a file to a location which should be prohibited
    private func checkWrite() throws {
        do {
            let path = "/private/file.txt"
            let text = "Text"
            try text.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            try FileManager.default.removeItem(atPath: path)
        }
        catch {
            // If one of the above throws, the device is likely not jailbroken.
            return
        }
        
        // Writing succeeded, device might be jailbroken.
        throw JBError.writeFileSucceeded
    }
    
    private func openApp() throws {
        if let url = URL(string: "cydia://package/com.example.package"), UIApplication.shared.canOpenURL(url) {
            throw JBError.appInstalled
        }
    }
}
