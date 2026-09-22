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

    // TODO: Simplify this computed values for the current flavor for each mock extension
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

        public static var green: Self {
            let m = MockAppFlavorService()
            m.current = .green
            m.targetName = "Threema"
            m.appName = "Threema Green"
            m.localizedAppName = "Threema"
            m.isSandbox = true
            m.isBusinessApp = false
            m.isWork = false
            m.isOnPrem = false
            m.isCustomOnPrem = false
            return m
        }

        public static var `private`: Self {
            let m = MockAppFlavorService()
            m.current = .threema
            m.targetName = "Threema"
            m.appName = "Threema"
            m.localizedAppName = "Threema"
            m.isSandbox = false
            m.isBusinessApp = false
            m.isWork = false
            m.isOnPrem = false
            m.isCustomOnPrem = false
            return m
        }

        public static var blue: Self {
            let m = MockAppFlavorService()
            m.current = .blue
            m.targetName = "ThreemaBlue"
            m.appName = "Threema Blue"
            m.localizedAppName = "Threema"
            m.isSandbox = true
            m.isBusinessApp = true
            m.isWork = true
            m.isOnPrem = false
            m.isCustomOnPrem = false
            return m
        }

        public static var work: Self {
            let m = MockAppFlavorService()
            m.current = .work
            m.targetName = "ThreemaWork"
            m.appName = "Threema Work"
            m.localizedAppName = "Threema"
            m.isSandbox = false
            m.isBusinessApp = true
            m.isWork = true
            m.isOnPrem = false
            m.isCustomOnPrem = false
            return m
        }

        public static var onPrem: Self {
            let m = MockAppFlavorService()
            m.current = .onPrem
            m.targetName = "Threema OnPrem"
            m.appName = "Threema OnPrem"
            m.localizedAppName = "Threema"
            m.isSandbox = false
            m.isBusinessApp = true
            m.isWork = false
            m.isOnPrem = true
            m.isCustomOnPrem = false
            return m
        }
        
        public static var customOnPrem: Self {
            let m = MockAppFlavorService()
            m.current = .customOnPrem
            m.targetName = "Custom OnPrem"
            m.appName = "Custom OnPrem"
            m.localizedAppName = "Custom"
            m.isSandbox = false
            m.isBusinessApp = true
            m.isWork = false
            m.isOnPrem = false
            m.isCustomOnPrem = true
            return m
        }
    }

#endif
