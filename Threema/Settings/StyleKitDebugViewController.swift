//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

class StyleKitDebugViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scrollView = UIScrollView()
        let debugStackView = StyleKit.debugStackView()
        
        scrollView.addSubview(debugStackView)
        view.addSubview(scrollView)
        
        debugStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            debugStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            debugStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            debugStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            debugStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}
