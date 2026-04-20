/// Service wrapper around the TargetManager static enum, useful for dependency injection when logic depends on the app
/// flavor.
public struct AppFlavorService: AppFlavorServiceProtocol {
    public init() { /* no-op */ }

    public var current: TargetManager { TargetManager.current }

    public var targetName: String { TargetManager.targetName }

    public var appName: String { TargetManager.appName }

    public var localizedAppName: String { TargetManager.localizedAppName }

    public var rateLink: URL? { TargetManager.rateLink }

    public var isSandbox: Bool { TargetManager.isSandbox }

    public var isBusinessApp: Bool { TargetManager.isBusinessApp }

    public var isWork: Bool { TargetManager.isWork }

    public var isOnPrem: Bool { TargetManager.isOnPrem }

    public var isCustomOnPrem: Bool { TargetManager.isCustomOnPrem }
}
