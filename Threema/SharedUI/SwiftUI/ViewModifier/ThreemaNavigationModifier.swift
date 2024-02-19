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

struct ThreemaNavigationModifier<ViewDestination: ViewDestinationRepresentable>: ViewModifier {
    @EnvironmentObject var navigator: Navigator<ViewDestination>

    func body(content: Content) -> some View {
        content.background {
            if let path = navigator.path {
                ThreemaNavigationLink(path).hidden()
            }
        }
    }
}

extension View {
    func navigationDestination<ViewDestination: ViewDestinationRepresentable>(
        for viewDestination: ViewDestination
            .Type
    ) -> some View {
        modifier(ThreemaNavigationModifier<ViewDestination>())
    }
    
    func navigationDestination<ViewDestination: ViewDestinationRepresentable>(
        for viewDestination: ViewDestination.Type,
        with navigator: Navigator<ViewDestination>
    ) -> some View {
        modifier(ThreemaNavigationModifier<ViewDestination>())
            .environmentObject(navigator)
    }
}
