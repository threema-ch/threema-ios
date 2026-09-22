import Foundation
import ThreemaFramework

/// A configurable implementation of `AppFlavorServiceProtocol` for testing
struct AppFlavorServiceMock: AppFlavorServiceProtocol {

    var current: TargetManager = .threema
    var targetName = "Threema"
    var appName = "Threema"
    var localizedAppName = "Threema"
    var rateLink: URL?
    var isSandbox = false
    var isBusinessApp = false
    var isWork = false
    var isOnPrem = false
    var isCustomOnPrem = false

    // MARK: - Flavors

    static let threema = AppFlavorServiceMock()

    static let work = AppFlavorServiceMock(
        current: .work,
        targetName: "ThreemaWork",
        appName: "Threema Work",
        isBusinessApp: true,
        isWork: true
    )

    static let onPrem = AppFlavorServiceMock(
        current: .onPrem,
        targetName: "ThreemaOnPrem",
        appName: "Threema OnPrem",
        isBusinessApp: true,
        isOnPrem: true
    )

    static let customOnPrem = AppFlavorServiceMock(
        current: .customOnPrem,
        targetName: "CustomOnPrem",
        appName: "Custom OnPrem",
        isBusinessApp: true,
        isOnPrem: true,
        isCustomOnPrem: true
    )
}
