import UIKit

@main
enum AppLauncher {
    static func main() {
        ignoreSIGPIPE()

        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(delegateClass())
        )
    }

    /// Ignore `SIGPIPE` process-wide.
    ///
    /// Threema Web's SaltyRTC WebSocket is created by the Rust `tokio-core`/`mio`/`net2` stack,
    /// which, unlike `std::net`, CFNetwork and `GCDAsyncSocket`, never sets `SO_NOSIGPIPE` on the
    /// socket. If the relay server closes the connection while the app is suspended, the next write
    /// on that socket fails with `EPIPE` and the kernel posts a *process-directed* `SIGPIPE`
    /// (`psignal(p, SIGPIPE)` in XNU's `soo_write()`). It is then delivered to an arbitrary thread,
    /// usually the main thread, and kills the app with a stack trace unrelated to the failing write.
    ///
    /// With the signal ignored the write just returns `EPIPE`, which the networking code already
    /// handles as a closed connection.
    ///
    /// - Note: Must be re-applied after `SentrySDK.start()`, which installs its own fatal signal
    ///         handler for `SIGPIPE`. See `SentryClient.start()`.
    static func ignoreSIGPIPE() {
        signal(SIGPIPE, SIG_IGN)
    }

    private static func delegateClass() -> AnyClass {
        let delegateClass: AnyClass

        #if DEBUG
            if AppLaunchMode.isTestingOrPreviewing {
                delegateClass = TestApplicationDelegate.self
            }
            else {
                delegateClass = ApplicationDelegate.self
            }
        #else
            delegateClass = ApplicationDelegate.self
        #endif

        return delegateClass
    }
}
