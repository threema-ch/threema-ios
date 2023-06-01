//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import SwiftUI
import UIKit

public class WallpaperStore {
    
    public static let shared = WallpaperStore()
    
    public let defaultWallPaper: UIImage = BundleUtil.imageNamed("ChatBackground")!
        .draw(withTintColor: Colors.backgroundChatLines)
    
    // MARK: - Public Functions
    
    /// Creates a unique filename and saves it with the conversationID as key in AppDefaults. The wallpaper is saved as NSData in the filesystem.
    /// - Parameters:
    ///   - conversationID: ID of the conversation which is used as the key for saving the reference to the wallpaper
    ///   - wallpaperData: The data of the wallpaper
    public func saveWallpaper(_ wallpaper: UIImage, for conversationID: NSManagedObjectID) {
        let key = conversationID.uriRepresentation().absoluteString
        var wallpapers: [String: String] = AppGroup.userDefaults()
            .dictionary(forKey: Constants.wallpaperKey) as? [String: String] ?? [String: String]()
        
        let filename = wallpapers[key] ?? uniqueFilename()
        let wallpaperPath: URL = wallpaperPath(filename: filename)
        
        FileUtility.write(fileURL: wallpaperPath, contents: MediaConverter.pngRepresentation(for: wallpaper))
        
        wallpapers.updateValue(filename, forKey: key)
        
        setAppDefaults(wallpapers: wallpapers as [String: Any], key: Constants.wallpaperKey)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationWallpaperChanged), object: nil)
    }
    
    public func saveDefaultWallpaper(_ wallpaper: UIImage?) {
        if let wallpaper {
            UserSettings.shared().wallpaper = MediaConverter.pngRepresentation(for: wallpaper)
        }
        else {
            UserSettings.shared().wallpaper = nil
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationWallpaperChanged), object: nil)
    }
    
    /// Fetches the wallpaper for the conversationID if there is one, if not it returns the current default wallpaper
    /// - Parameter conversationID: ID of the conversation to load the wallpaper for
    /// - Returns: The Data of the Wallpaper
    public func wallpaper(for conversationID: NSManagedObjectID) -> UIImage? {
        let key = conversationID.uriRepresentation().absoluteString
        
        if let wallpapers = AppGroup.userDefaults().dictionary(forKey: Constants.wallpaperKey),
           let filename = wallpapers[key] as? String,
           let data = FileUtility.read(fileURL: wallpaperPath(filename: filename)),
           let wallpaper = UIImage(data: data) {
            return wallpaper
        }
        else if let data = BusinessInjector().userSettings.wallpaper,
                let wallpaper = UIImage(data: data) {
            return wallpaper
        }
        else {
            return nil
        }
    }
    
    public func hasCustomWallpaper(for conversationID: NSManagedObjectID) -> Bool {
        let key = conversationID.uriRepresentation().absoluteString
        let wallpapers: [String: String] = AppGroup.userDefaults()
            .dictionary(forKey: Constants.wallpaperKey) as? [String: String] ?? [String: String]()
        return wallpapers[key] != nil
    }
    
    /// Deletes the wallpaper for the given conversationID
    /// - Parameter conversationID: ID of the conversation for which the wallpaper needs to be deleted
    public func deleteWallpaper(for conversationID: NSManagedObjectID) {
        let key = conversationID.uriRepresentation().absoluteString
        let wallpapers = AppGroup.userDefaults().dictionary(forKey: Constants.wallpaperKey)
        if var wallpapers = wallpapers, let filename = wallpapers[key] as? String {
            let wallpaperPath = wallpaperPath(filename: filename)
            FileUtility.delete(at: wallpaperPath)
            wallpapers.removeValue(forKey: key)
            
            setAppDefaults(wallpapers: wallpapers, key: Constants.wallpaperKey)
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationWallpaperChanged),
                object: nil
            )
        }
    }
    
    /// Deletes all custom wallpapers for every conversation
    public func deleteAllCustom() {
        if let wallpapers = AppGroup.userDefaults().dictionary(forKey: Constants.wallpaperKey) {
            for wallpaperEntry in wallpapers {
                let wallpaperPath = wallpaperPath(filename: wallpaperEntry.key)
                FileUtility.delete(at: wallpaperPath)
            }
        }
        setAppDefaults(wallpapers: Dictionary(), key: Constants.wallpaperKey)
        
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: kNotificationWallpaperChanged),
            object: nil
        )
    }
   
    public func currentDefaultWallpaper() -> UIImage? {
        if let wallpaper = BusinessInjector().userSettings.wallpaper {
            return UIImage(data: wallpaper)
        }
        return nil
    }
    
    public func defaultIsThreemaWallpaper() -> Bool {
        UserSettings.shared().wallpaper == MediaConverter.pngRepresentation(for: defaultWallPaper)
    }
    
    public func defaultIsEmptyWallpaper() -> Bool {
        UserSettings.shared().wallpaper == nil
    }
    
    // MARK: - Private Functions
    
    private func setAppDefaults(wallpapers: [String: Any]?, key: String) {
        AppGroup.userDefaults().set(wallpapers, forKey: key)
        AppGroup.userDefaults().synchronize()
    }
    
    private func wallpaperPath(filename: String) -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path)[0]
        let docURL = URL(fileURLWithPath: documentsDir)
        return docURL.appendingPathComponent(filename)
    }
    
    private func uniqueFilename() -> String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path)[0]
        let docURL = URL(fileURLWithPath: documentsDir)
        return FileUtility.getUniqueFilename(from: Constants.wallpaperKey, directoryURL: docURL, pathExtension: nil)
    }
}
