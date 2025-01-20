//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

extension EnvironmentValues {
    @Entry var contentSize: CGSize = .zero
    @Entry var edgeInsets: EdgeInsets = .init()
}

/// A view modifier that observes and provides the size and safe area insets of its content.
private struct ViewSizeObservationEnvironment: ViewModifier {
    @State private var contentSize: CGSize = .zero
    @State private var edgeInsets: EdgeInsets = .init()
    
    /// Modifies the body of the content to include size and edge insets observation.
    func body(content: Content) -> some View {
        content
            .background(content: {
                GeometryReader { geometry in
                    Task { @MainActor in
                        edgeInsets = geometry.safeAreaInsets
                        contentSize = geometry.size
                    }
                    
                    return Color.clear
                }
            })
            .environment(\.contentSize, contentSize)
            .environment(\.edgeInsets, edgeInsets)
    }
}

extension View {
    /// Applies the `ViewSizeObservationEnvironment` modifier to a view.
    /// This Modifier should only be used once per view hierarchy and is only intended for root views that sit inside a
    /// container like `.sheet` for example.
    /// `@Environment` are accessible downstream to all `View`s.
    /// # Example usage:
    /// ```swift
    ///     struct ContentView: View {
    ///         var body: some View {
    ///             VStack {}.sheet(...) {
    ///                 SheetView()
    ///                     .registerSizeObserver()
    ///             }
    ///         }
    ///     }
    /// ```
    ///
    /// ```swift
    ///     struct SheetView: View {
    ///         @Environment(\.contentSize) var contentSize
    ///         @Environment(\.edgeInsets) var edgeInsets
    ///         var body: some View {
    ///             // both values taken from the UISheetPresentationController.view
    ///         }
    ///     }
    /// ```
    public func registerSizeObserver() -> some View {
        modifier(ViewSizeObservationEnvironment())
    }
}
