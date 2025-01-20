//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

/// Current app setup state
///
/// Use `AppSetup` to get and set the current state
@objc public enum AppSetupState: Int, CustomStringConvertible {
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
