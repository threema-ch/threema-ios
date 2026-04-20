/// Current app setup state
///
/// - Important: When adding a new case, you have to implement it here `MDMSetup.appSetupStateFromRawValue(_)` too!
///
/// Use `AppSetup` to get and set the current state
@objc public enum AppSetupState: Int, CustomStringConvertible, CaseIterable {
    // We leave 0 empty as this is the default value if the setting is not set and thus should lead to a reevaluation of
    // the current state.
    // We also leave 9 numbers between state to maybe introduce more states later on.
    
    /// No setup done
    case notSetup = 10
    
    /// An identity was added (through creation or a restore)
    case identityAdded = 20
    
    /// The identity setup is complete
    case identitySetupComplete = 30
    
    /// The setup is completely completed
    case complete = 40

    // MARK: CustomStringConvertible
    
    public var description: String {
        switch self {
        case .notSetup:
            "notSetup"
        case .identityAdded:
            "identityAdded"
        case .identitySetupComplete:
            "identitySetupComplete"
        case .complete:
            "complete"
        }
    }
}
