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
import ThreemaMacros

extension View {
    var topViewController: UIViewController? {
        AppDelegate.shared().currentTopViewController()
    }
    
    var asAnyView: AnyView {
        AnyView(self)
    }
    
    var isModallyPresented: Bool {
        topViewController is ModalNavigationController
    }
    
    var wrappedNavigationView: some View {
        isModallyPresented
            ? onAppear {
                (topViewController as? ModalNavigationController).map {
                    BrandingUtils.updateTitleLogo(in: $0)
                }
            }.asAnyView
            : NavigationView { self }.asAnyView
    }
    
    func apply(@ViewBuilder _ apply: (Self) -> some View) -> some View {
        apply(self)
    }
    
    func applyIf(_ condition: Bool, apply: (Self) -> AnyView) -> AnyView {
        condition ? apply(self) : asAnyView
    }
    
    func applyIf(_ condition: Bool, apply: (Self) -> some View) -> some View {
        condition ? apply(self).asAnyView : asAnyView
    }
    
    func applyScrollBounceBahaviorIfNeeded() -> AnyView {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.basedOnSize, axes: [.vertical]).asAnyView
        }
        else {
            asAnyView
        }
    }
    
    func threemaNavigationBar(_ title: String) -> some View {
        ignoresSafeArea(.all)
            .navigationBarTitle(
                title,
                displayMode: .inline
            )
    }
}
