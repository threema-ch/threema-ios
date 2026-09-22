import Foundation
import PromiseKit

public enum PromiseKitConfiguration {
    public static func configurePromiseKit() {
        // All then-type handlers to run on a background, "finalizers" like done or catch runs on main queue
        PromiseKit.conf.Q.map = .global()
        PromiseKit.conf.Q.return = .main
    }
}
