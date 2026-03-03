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

protocol ModalRouting: AnyObject {
    var rootViewController: UIViewController { get }
    
    func present(
        _ viewController: UIViewController,
        animated: Bool,
        style: UIModalPresentationStyle,
        transition: UIModalTransitionStyle,
        completion: (() -> Void)?
    )
}

extension ModalRouting {
    func present(
        _ viewController: UIViewController,
        animated: Bool = true,
        style: UIModalPresentationStyle = .automatic,
        transition: UIModalTransitionStyle = .coverVertical,
        completion: (() -> Void)? = nil
    ) {
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = style
        navigationController.modalTransitionStyle = transition
        rootViewController.present(
            navigationController,
            animated: animated,
            completion: completion
        )
    }
}

final class ModalRouter: ModalRouting {
    let rootViewController: UIViewController
    
    init(rootViewController: UIViewController) {
        self.rootViewController = rootViewController
    }
}
