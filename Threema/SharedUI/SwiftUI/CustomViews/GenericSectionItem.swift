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

protocol ViewDestinationProtocol {
    associatedtype ViewDestination: ViewDestinationRepresentable
    var viewDestination: ViewDestination? { get }
}

struct GenericSectionItem<
    E: ObservableObject,
    Destination: View,
    Label: View,
    ViewDestination: ViewDestinationRepresentable
>: View, SectionItemProtocol {
    @EnvironmentObject var environmentObject: E
    
    var action: (() -> Void)?
    var destination: Destination?
    var label: Label
    var locked: Bool
    var viewDestination: ViewDestination?
    
    var body: some View {
        if let action {
            if locked {
                LockedButtonNavigationLink {
                    action()
                } label: {
                    label
                }
            }
            else {
                ButtonNavigationLink {
                    action()
                } label: {
                    label
                }
            }
        }
        else if let destination {
            if locked {
                LockedNavigationLink(shouldNavigate: Binding.constant(false)) {
                    label
                } destination: {
                    destination
                        .environmentObject(environmentObject)
                }
            }
            else {
                NavigationLink {
                    destination
                        .environmentObject(environmentObject)
                } label: {
                    label
                }
            }
        }
        else if let viewDestination {
            ThreemaNavigationLink(viewDestination) {
                label
            }
        }
        else {
            EmptyView()
        }
    }
}

extension SectionItemProtocol {
    func makeItemView() -> some View {
        GenericSectionItem<Self.ObservableEnvironment, Self.Destination, Self.Label, Self.ViewDestination>(self)
            .environmentObject(environmentObject)
    }
}

extension GenericSectionItem {
    init<S: SectionItemProtocol>(_ sectionItem: S) where Destination == S.Destination, Label == S.Label,
        ViewDestination == S.ViewDestination {
        self.init(
            action: sectionItem.action,
            destination: sectionItem.destination,
            label: sectionItem.label,
            locked: sectionItem.locked,
            viewDestination: sectionItem.viewDestination
        )
    }
    
    init(
        viewDestination: ViewDestination,
        @ViewBuilder label: @escaping () -> Label
    ) where Destination == AnyView {
        self.action = nil
        self.locked = false
        self.destination = nil
        self.label = label()
        self.viewDestination = viewDestination
    }
    
    init(
        locked: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) where Destination == AnyView, ViewDestination == EmptyViewDestination {
        self.action = action
        self.locked = locked
        self.destination = nil
        self.label = label()
        self.viewDestination = nil
    }

    init(
        locked: Bool = false,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.locked = locked
        self.action = nil
        self.destination = destination()
        self.label = label()
        self.viewDestination = nil
    }
}
