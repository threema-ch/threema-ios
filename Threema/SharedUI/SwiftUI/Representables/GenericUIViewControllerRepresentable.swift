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

import SwiftUI
import ThreemaFramework

extension UIViewController {
    fileprivate struct WrapperView<V: UIViewController>: UIViewControllerRepresentable {
        typealias CreateViewController = () -> (V?)
        
        private let makeUIViewController: CreateViewController
        
        init(_ makeUIViewController: @escaping CreateViewController) {
            self.makeUIViewController = makeUIViewController
        }
 
        func makeUIViewController(context: Context) -> V {
            makeUIViewController() ?? V()
        }
        
        func updateUIViewController(_ uiViewController: V, context: Context) { }
        
        static func dismantleUIViewController(_ uiViewController: V, coordinator: ()) {
            NotificationCenter.default.removeObserver(uiViewController)
        }
    }
    
    private var wrappedView: some View {
        WrapperView { [weak self] in
            guard let self else {
                return nil
            }
            return self
        }
    }
    
    var wrappedModalNavigationView: some View {
        uiViewController(ModalNavigationController(rootViewController: self))
    }
    
    func wrappedModalNavigationView(delegate: UINavigationControllerDelegate) -> some View {
        uiViewController(
            ModalNavigationController(rootViewController: self).then {
                $0.delegate = delegate
            }
        )
    }
}

func uiViewController(_ vc: @autoclosure @escaping () -> UIViewController) -> some View {
    UIViewController.WrapperView {
        vc()
    }
}
