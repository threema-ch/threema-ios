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

struct ButtonNavigationLink<Content: View>: View {
    
    var action: () -> Void
    var label: () -> Content

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                label()
                    .padding(.trailing)
                NavigationLink.empty
            }
        }
        .tint(Color.primary)
    }
}

struct ModalNavigationLink<Content: View, Label: View>: View {
    @State private var isPresented = false

    var destination: () -> Content
    var label: () -> Label
    var onDismiss: () -> Void
    var fullscreen = false

    var body: some View {
        ButtonNavigationLink {
            isPresented.toggle()
        } label: {
            label()
        }.background {
            if fullscreen {
                VStack { }.fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
                    destination()
                }
            }
            else {
                VStack { }.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                    destination()
                }
            }
        }
    }
}

struct LockedModalNavigationLink<Content: View, Label: View>: View {
    @State private var isPresented = false
    
    var destination: () -> Content
    var label: () -> Label

    var body: some View {
        LockedButtonNavigationLink {
            isPresented.toggle()
        } label: {
            label()
        }
        .sheet(isPresented: $isPresented) {
            destination()
        }
    }
}

struct LockedButtonNavigationLink<Content: View>: View {

    @State private var showLockscreen = false

    var action: () -> Void
    var label: () -> Content

    var body: some View {
        ButtonNavigationLink {
            KKPasscodeLock.shared().isPasscodeRequired() ? {
                showLockscreen = true
            }() : action()
        } label: {
            label()
        }
        .sheet(isPresented: $showLockscreen) {
            LockScreenView {
                action()
            } cancelled: { } didDismissAfterSuccess: { }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct LockedNavigationLink<Content: View, Label: View>: View {
    
    @State private var showLockscreen = false
    @State private var isActive = false
    
    @Binding var shouldNavigate: Bool
    
    private var shouldShowLockScreen: Binding<Bool> {
        shouldNavigate && KKPasscodeLock.shared().isPasscodeRequired() ? Binding.constant(true) : $showLockscreen
    }

    var label: () -> Content
    var destination: () -> Label
    
    var body: some View {
        Button {
            KKPasscodeLock.shared().isPasscodeRequired() ? {
                showLockscreen = true
            }() : {
                isActive = true
            }()
        } label: {
            ZStack {
                label()
                    .padding(.trailing)
                NavigationLink(destination: destination(), isActive: $isActive) {
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: shouldShowLockScreen) {
            LockScreenView {
                shouldNavigate = false
                isActive = true
            } cancelled: { }
                .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            if !shouldNavigate {
                isActive = false
            }
        }
        .tint(Color.primary)
    }
}

struct ThreemaNavigationLink<Label: View, ViewDestination: ViewDestinationRepresentable>: View {
    @EnvironmentObject var navigator: Navigator<ViewDestination>
    var viewDestination: ViewDestination
    var label: () -> Label
    
    init(_ viewDestination: ViewDestination, label: @escaping () -> Label) {
        self.viewDestination = viewDestination
        self.label = label
    }
 
    var body: some View {
        NavigationLink(
            tag: viewDestination,
            selection: $navigator.path,
            destination: {
                viewDestination.view.asAnyView
            },
            label: label
        )
    }
}

extension ThreemaNavigationLink {
    init(_ viewDestination: ViewDestination) where Label == EmptyView {
        self.init(viewDestination) {
            EmptyView()
        }
    }
}

protocol ThemedViewControllerRepresentable: View {
    /// Add additional setup before the view is presented
    var title: String { get }
    /// Used for `tabBarItem.image`
    var largeTitle: Bool { get }
    /// Used for `navigationController.navigationBar.prefersLargeTitles`
    var systemImageName: String { get }
    /// Used for `tabBarItem.title` and `navigationItem.title`
    var setup: (inout ThemedTableViewControllerSwiftUI) -> Void { get }
}

extension ThemedViewControllerRepresentable {
    func navigationController() -> UINavigationController {
        let navC = ThemedNavigationController(navigationBarClass: StatusNavigationBar.self, toolbarClass: nil)
        navC.navigationBar.prefersLargeTitles = largeTitle
        var c = ThemedTableViewControllerSwiftUI(navTitle: title, hostedView: self)
        c.title = title
        c.tabBarItem.title = title
        c.navigationItem.title = title
        navC.pushViewController(c, animated: false)
        navC.tabBarItem.image = UIImage(systemName: systemImageName)
        navC.tabBarItem.title = title
        navC.navigationItem.title = title
        setup(&c)
        return navC
    }
}
