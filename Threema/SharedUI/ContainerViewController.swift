//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import UIKit

class ContainerViewController: UIViewController {
    private(set) var viewControllers: [UIViewController] = []
    private var currentViewController: UIViewController?

    init(_ viewControllers: [UIViewController] = []) {
        super.init(nibName: nil, bundle: nil)
        self.viewControllers = viewControllers
    }
    
    convenience init(@ArrayBuilder<UIViewController> _ viewControllers: () -> [UIViewController]) {
        self.init(viewControllers())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func switchToViewController(at index: Int) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        addChild(viewControllers[index])
        view.addSubview(viewControllers[index].view)
        viewControllers[index].didMove(toParent: self)
        currentViewController = viewControllers[index]
        viewControllers[index].view.frame = view.bounds
    }
}
