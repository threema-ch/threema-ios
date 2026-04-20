import CocoaLumberjackSwift
import FileUtility
import Foundation
import SwiftUI
import UIKit

public protocol WallpaperStoreProtocol {
    var defaultWallPaper: UIImage! { get }
    func saveWallpaper(_ wallpaper: UIImage, for conversationID: NSManagedObjectID)
    func saveDefaultWallpaper(_ wallpaper: UIImage?)
    func wallpaper(for conversationID: NSManagedObjectID) -> UIImage?
    func hasCustomWallpaper(for conversationID: NSManagedObjectID) -> Bool
    func deleteWallpaper(for conversationID: NSManagedObjectID)
    func deleteAllCustom()
    func currentDefaultWallpaper() -> UIImage?
    func wallpaperType() -> WallpaperType
}

public final class WallpaperStore: WallpaperStoreProtocol {
        
    public static let shared = WallpaperStore(fileUtility: FileUtility.shared)
    
    public lazy var defaultWallPaper: UIImage! = UIImage(resource: .chatBackground)
    
    let fileUtility: FileUtilityProtocol
    
    init(fileUtility: FileUtilityProtocol) {
        self.fileUtility = fileUtility
    }
    
    // MARK: - Public Functions
    
    /// Creates a unique filename and saves it with the conversationID as key in AppDefaults. The wallpaper is saved as
    /// NSData in the filesystem.
    /// - Parameters:
    ///   - conversationID: ID of the conversation which is used as the key for saving the reference to the wallpaper
    ///   - wallpaperData: The data of the wallpaper
    public func saveWallpaper(_ wallpaper: UIImage, for conversationID: NSManagedObjectID) {
        let key = conversationID.uriRepresentation().absoluteString
        var wallpapers: [String: String] = AppGroup.userDefaults()
            .dictionary(forKey: Constants.wallpaperKey) as? [String: String] ?? [String: String]()
        
        guard
            let filename = wallpapers[key] ?? uniqueFilename(),
            let wallpaperPath: URL = wallpaperPath(filename: filename)
        else {
            return
        }
        
        let compressed = compressImageData(wallpaper.pngData())
        fileUtility.write(contents: compressed, to: wallpaperPath)
        
        wallpapers.updateValue(filename, forKey: key)
        
        setAppDefaults(wallpapers: wallpapers as [String: Any], key: Constants.wallpaperKey)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationWallpaperChanged), object: nil)
    }
    
    public func saveDefaultWallpaper(_ wallpaper: UIImage?) {
        if let wallpaper {
            let compressed = compressImageData(wallpaper.pngData())
            UserSettings.shared().wallpaper = compressed
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
           let data = fileUtility.read(fileURL: wallpaperPath(filename: filename)),
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
        if var wallpapers, let filename = wallpapers[key] as? String {
            let wallpaperPath = wallpaperPath(filename: filename)
            fileUtility.deleteIfExists(at: wallpaperPath)
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
                fileUtility.deleteIfExists(at: wallpaperPath)
            }
        }
        setAppDefaults(wallpapers: Dictionary(), key: Constants.wallpaperKey)
        
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: kNotificationWallpaperChanged),
            object: nil
        )
    }
   
    public func currentDefaultWallpaper() -> UIImage? {
        let businessInjector = BusinessInjector()
        switch businessInjector.userSettings.wallpaperType {
        case WallpaperType.empty:
            return nil
        case WallpaperType.threema:
            return defaultWallPaper
        case WallpaperType.custom:
            return UIImage(data: businessInjector.userSettings.wallpaper)
        @unknown default:
            return nil
        }
    }
    
    public func wallpaperType() -> WallpaperType {
        BusinessInjector().userSettings.wallpaperType
    }
    
    // MARK: - Private Functions
    
    private func setAppDefaults(wallpapers: [String: Any]?, key: String) {
        AppGroup.userDefaults().set(wallpapers, forKey: key)
        AppGroup.userDefaults().synchronize()
    }
    
    private func wallpaperPath(filename: String) -> URL? {
        fileUtility.appDocumentsDirectory.map {
            $0.appendingPathComponent(filename)
        }
    }
    
    private func uniqueFilename() -> String? {
        fileUtility.appDocumentsDirectory.map {
            fileUtility.getUniqueFilename(
                from: Constants.wallpaperKey,
                directoryURL: $0,
                pathExtension: nil
            )
        }
    }
        
    /// Compresses de passed in image data until it's smaller than the maximal size defined in the function
    /// - Parameter data: Image data to compress
    /// - Returns: Compressed data or original if is already smaller than size
    private func compressImageData(_ data: Data?) -> Data? {
        let maxSize = 1_500_000
        
        guard let data, data.count >= maxSize else {
            return data
        }
       
        DDLogInfo("[WallpaperStore] Compressing image data. Original size: \(data.count)")
        
        guard let compressed = MediaConverter.scaleImageData(
            to: data,
            toMaxSize: max(UIScreen.main.bounds.width, UIScreen.main.bounds.height),
            useJPEG: true,
            withQuality: 1
        ) else {
            return data
        }
        
        DDLogInfo("[WallpaperStore] Compressed image data. Final size: \(compressed.count)")
      
        return compressed
    }
}
