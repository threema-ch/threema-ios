//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import WebRTC

extension RTCCertificate {
    /// Hex encoded fingerprint of the DER representation
    var groupCallFingerprint: Data? {
        let internalFingerprint = fingerprint
        
        guard let reg = try? NSRegularExpression(pattern: "^sha-256 (?<hex>([0-9a-zA-Z]{2}:?){32})$") else {
            DDLogError("[GroupCall] Unable to initialize Regex for fingerprint")
            return nil
        }
        
        let matches = reg.matches(
            in: internalFingerprint,
            range: NSRange(location: 0, length: internalFingerprint.count)
        )
        
        var actualFingerPrint: String?
        
        if let match = matches.first {
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: internalFingerprint) {
                actualFingerPrint = String(internalFingerprint[swiftRange])
            }
        }
        
        guard let actualFingerPrint else {
            DDLogError("[GroupCall] No matches found for fingerprint")
            return nil
        }
        
        guard let certificateBytes = actualFingerPrint.replacingOccurrences(of: ":", with: "").hexadecimal else {
            DDLogError("[GroupCall] Unable to convert fingerprint to hex representation")
            return nil
        }
        
        return certificateBytes
    }
}
