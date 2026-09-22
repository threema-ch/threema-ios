#if DEBUG
    import ThreemaFramework
    import UIKit

    /// Minimal application delegate used for previews, playgrounds & tests instead of `ApplicationDelegate`
    ///
    /// Since the iOS 27 SDK UIKit terminates the app during launch if it detects no scene life cycle adoption. As our
    /// `Info.plist`s don't contain any `UISceneConfigurations` this delegate needs to provide a scene configuration
    final class TestApplicationDelegate: UIResponder, UIApplicationDelegate {

        /// We don't run the launch sequence here, but shared singletons resolve their storage through
        /// `AppGroup`, which asserts if no IDs were set. A preview reaching e.g. `UserSettings.shared()` (as
        /// `ThreemaEnvironment`s debug feature flags do) would thus crash the canvas. Setting the IDs is the part of
        /// `AppLaunchManager.preLaunchSetup()` that has no further side effects, so we do that — and only that — at
        /// the same point of the life cycle as `ApplicationDelegate`.
        override init() {
            super.init()

            AppGroup.setGroupID(BundleUtil.threemaAppGroupIdentifier())
            BundleUtil.mainBundle()?.bundleIdentifier.map(AppGroup.setAppID(_:))
        }

        func application(
            _ application: UIApplication,
            configurationForConnecting connectingSceneSession: UISceneSession,
            options: UIScene.ConnectionOptions
        ) -> UISceneConfiguration {
            let configuration = UISceneConfiguration(
                name: "Previews, Playgrounds & Tests Scene",
                sessionRole: connectingSceneSession.role
            )
            configuration.delegateClass = TestApplicationSceneDelegate.self

            return configuration
        }
    }
#endif
