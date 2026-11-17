import Foundation
@testable import ThreemaFramework

final class WallpaperStoreMock: WallpaperStoreProtocol {
    var defaultWallPaper: UIImage! = nil

    func saveWallpaper(_ wallpaper: UIImage, for conversationID: NSManagedObjectID, screenBounds: CGRect) {
        // no-op
    }

    func saveDefaultWallpaper(_ wallpaper: UIImage, screenBounds: CGRect) {
        // no-op
    }

    func deleteDefaultWallpaper() {
        // no-op
    }

    func wallpaper(for conversationID: NSManagedObjectID) -> UIImage? {
        nil
    }

    func hasCustomWallpaper(for conversationID: NSManagedObjectID) -> Bool {
        false
    }

    func deleteWallpaper(for conversationID: NSManagedObjectID) {
        // no-op
    }

    func deleteAllCustom() {
        // no-op
    }

    func currentDefaultWallpaper() -> UIImage? {
        nil
    }

    func wallpaperType() -> WallpaperType {
        .empty
    }
}
