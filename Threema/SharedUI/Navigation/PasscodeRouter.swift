//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import ThreemaFramework

protocol PasscodeRouting: AnyObject {
    var lockScreen: LockScreen { get }
    var isPasscodeRequired: () -> Bool { get }
    var rootViewController: UIViewController { get }
    
    func requireAuthenticationIfNeeded(onSuccess: @escaping () -> Void)
}

extension PasscodeRouting {
    func requireAuthenticationIfNeeded(onSuccess: @escaping () -> Void) {
        guard isPasscodeRequired() else {
            onSuccess()
            return
        }
        
        lockScreen.presentLockScreenView(
            viewController: rootViewController,
            didDismissAfterSuccess: onSuccess
        )
    }
}

final class PasscodeRouter: PasscodeRouting {
    let lockScreen: LockScreen
    let isPasscodeRequired: () -> Bool
    let rootViewController: UIViewController
    
    init(
        lockScreen: LockScreen,
        isPasscodeRequired: @autoclosure @escaping () -> Bool,
        rootViewController: UIViewController
    ) {
        self.lockScreen = lockScreen
        self.isPasscodeRequired = isPasscodeRequired
        self.rootViewController = rootViewController
    }
}
