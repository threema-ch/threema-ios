import Foundation
import SwiftUI

/// A property wrapper for user settings that provides both direct and bindable access.
@propertyWrapper
public struct UserSetting<Value> {
    private let keyPath: ReferenceWritableKeyPath<UserSettings, Value>
    private var shouldExit: Bool

    /// Initializes a new instance of the user setting property wrapper.
    /// - Parameters:
    ///   - keyPath: A key path to the specific setting in `UserSettings`.
    ///   - shouldExit: A Boolean value that determines whether the application should exit after setting the value.
    public init(_ keyPath: ReferenceWritableKeyPath<UserSettings, Value>, shouldExit: Bool = false) {
        self.keyPath = keyPath
        self.shouldExit = shouldExit
    }

    /// The current value of the user setting.
    public var wrappedValue: Value {
        get { UserSettings.shared()[keyPath: keyPath] }
        set { UserSettings.shared()[keyPath: keyPath] = newValue }
    }

    /// A bindable version of the user setting that can be used in SwiftUI.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { UserSettings.shared()[keyPath: keyPath] },
            set: { UserSettings.shared()[keyPath: keyPath] = $0
                if shouldExit {
                    exit(1)
                }
            }
        )
    }
}
