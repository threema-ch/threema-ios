//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import MBProgressHUD

struct ProgressHUD {
    typealias Action = () -> Void
    
    private(set) var hide: Action?
    private(set) var show: Action?
    
    private init() { }
    
    static func make(label: String?) -> ProgressHUD {
        make(label: label, on: AppDelegate.shared().currentTopViewController())
    }
    
    static func make(label: String?, on viewController: UIViewController?) -> ProgressHUD {
        ProgressHUD().then {
            guard let viewController, let view = viewController.view else {
                return
            }
            
            $0.hide = {
                _ = MBProgressHUD.hide(for: view, animated: true)
            }
            
            $0.show = {
                _ = MBProgressHUD.showAdded(to: view, animated: true).then {
                    $0.label.text = label
                }
            }
        }
    }
}

// MARK: - Then

extension ProgressHUD: Then { }
