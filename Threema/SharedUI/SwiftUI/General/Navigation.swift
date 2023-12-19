//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
