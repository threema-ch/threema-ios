//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

@objc public class URLSenderItemCreator: NSObject {
    
    public static func getSenderItem(for url: URL, maxSize: ImageSenderItemSize?) -> URLSenderItem? {
        if !URLSenderItemCreator.validate(url: url) {
            return nil
        }
        let uti = UTIConverter.uti(forFileURL: url)
        if uti == nil {
            DDLogError("URLSender: unsupported url: \(url)")
            return nil
        }

        var item: URLSenderItem?
        
        if UTIConverter.conforms(toMovieType: uti) {
            let creator = VideoURLSenderItemCreator()
            item = creator.senderItem(from: url)
        }
        else if UTIConverter.conforms(toImageType: uti) {
            let creator =
                if let maxSize {
                    ImageURLSenderItemCreator(with: maxSize)
                }
                else {
                    ImageURLSenderItemCreator()
                }
            item = creator.senderItem(from: url)
        }
        else {
            item = URLSenderItem(url: url, type: uti, renderType: NSNumber(value: 0), sendAsFile: true)
        }
        return item
    }
    
    /// Will return a sender item for the file at url. The file will be transcoded or scaled and its metadata will be
    /// removed
    /// if it conforms to isMovieMimeType or isImageMimeType.
    /// - Parameter url: The url at which the file is stored
    /// - Returns: An url sender item if one can be created
    @objc public static func getSenderItem(for url: URL) -> URLSenderItem? {
        URLSenderItemCreator.getSenderItem(for: url, maxSize: nil)
    }
    
    private static func validate(url: URL) -> Bool {
        guard let scheme = url.scheme else {
            return false
        }
        if (scheme != "file") || !FileManager.default.fileExists(atPath: url.relativePath) {
            return false
        }
        return true
    }
}
