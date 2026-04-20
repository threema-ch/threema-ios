import UIKit

#if DEBUG
    private final class AppTestDelegate: UIResponder, UIApplicationDelegate { }
#endif

@main
enum AppLauncher {
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(delegateClass())
        )
    }
    
    private static func delegateClass() -> AnyClass {
        let delegateClass: AnyClass
        
        #if DEBUG
            let environment = ProcessInfo.processInfo.environment
            let isRunningPreviews = environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            let isRunningTests = CommandLine.argc > 1 && CommandLine.arguments[1] == "-isRunningForTests"

            if isRunningPreviews || isRunningTests {
                delegateClass = AppTestDelegate.self
            }
            else {
                #if SCENE_DELEGATE_ROOT_COORDINATOR_DEVELOPMENT
                    delegateClass = SceneDelegate.self
                #else
                    delegateClass = AppDelegate.self
                #endif
            }
        #else
            delegateClass = AppDelegate.self
        #endif
        
        return delegateClass
    }
}
