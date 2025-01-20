//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import SwiftUI

class Navigator<ViewDestination: ViewDestinationRepresentable>: ObservableObject {
    @Published var path: ViewDestination?
    
    private lazy var lockScreen = LockScreen(isLockScreenController: false)
    
    init(for: ViewDestination.Type = AnyViewDestination.self) {
        self.path = nil
    }
    
    func navigate(_ destinationPath: ViewDestination?, isLocked: Bool = false) {
        let navigation = {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.path = destinationPath
            }
        }
        
        if isLocked {
            guard let viewController = AppDelegate.shared().currentTopViewController() else {
                return
            }
            lockScreen.presentLockScreenView(
                viewController: viewController,
                enteredCorrectly: {
                    navigation()
                }
            )
        }
        else {
            navigation()
        }
    }
    
    func navigate(_ view: some View, isLocked: Bool = false) where ViewDestination == AnyViewDestination {
        navigate(view.anyViewDestination, isLocked: isLocked)
    }
}
