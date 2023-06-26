//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

@objc class ExternalStorage: NSObject {
    
    /// Get filename of entity fields AudioData.data, FileData.data, ImageData.data and VideoData.data.
    ///
    /// - Parameter data: Entity field of type 'Binary Data' and attribute 'Allows External Storage' is ON
    /// - Returns: Filename of external data
    @objc static func getFilename(data: NSData) -> String? {
        let filenameSelector = Selector(("filename"))
        if data.responds(to: filenameSelector) {
            return ExternalStorage.convertCfTypeToString(cfValue: data.perform(filenameSelector))
        }
        else {
            // If selector 'filename' missing, than getting filename from object description
            return ExternalStorage.getFilename(description: data.description)
        }
    }
    
    static func getFilename(description: String) -> String? {
        if let rangeStart = description.range(of: "path = ", options: .caseInsensitive, range: nil, locale: nil),
           let rangeEnd = description.range(
               of: " ;",
               options: .caseInsensitive,
               range: rangeStart.upperBound..<String.Index(utf16Offset: description.count, in: description),
               locale: nil
           ) {
            let filename = String(description[rangeStart.upperBound..<rangeEnd.lowerBound])
            if !filename.elementsEqual("nil") {
                return filename.replacingOccurrences(of: "\u{02}", with: "")
            }
        }
        return nil
    }
    
    private static func convertCfTypeToString(cfValue: Unmanaged<AnyObject>?) -> String? {
        if let cfValue {
            let value = Unmanaged.fromOpaque(cfValue.toOpaque()).takeUnretainedValue() as CFString
            if CFGetTypeID(value) == CFStringGetTypeID() {
                return value as String
            }
        }
        return nil
    }
}
