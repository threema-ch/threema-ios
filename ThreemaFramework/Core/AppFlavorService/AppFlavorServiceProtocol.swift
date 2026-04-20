public protocol AppFlavorServiceProtocol {
    var current: TargetManager { get }
    var targetName: String { get }
    var appName: String { get }
    var localizedAppName: String { get }
    var rateLink: URL? { get }
    var isSandbox: Bool { get }
    var isBusinessApp: Bool { get }
    var isWork: Bool { get }
    var isOnPrem: Bool { get }
    var isCustomOnPrem: Bool { get }
}

#if DEBUG

    public final class MockAppFlavorService: AppFlavorServiceProtocol {
        public var current: TargetManager = .threema

        public var targetName = "Threema"

        public var appName = "Threema"

        public var localizedAppName = "Threema"

        public var rateLink: URL? = ThreemaURLProvider.privateDownloadAppStore

        public var isSandbox = false

        public var isBusinessApp = false

        public var isWork = false

        public var isOnPrem = false

        public var isCustomOnPrem = false
    }

    extension AppFlavorServiceProtocol where Self == MockAppFlavorService {
        public static var mock: Self { MockAppFlavorService() }

        public static var onPrem: Self {
            let m = MockAppFlavorService()
            m.current = .onPrem
            m.targetName = "Threema OnPrem"
            m.appName = "Threema OnPrem"
            m.localizedAppName = "Threema"
            m.isSandbox = false
            m.isBusinessApp = false
            m.isWork = false
            m.isOnPrem = true
            m.isCustomOnPrem = true
            return m
        }
    }

#endif
