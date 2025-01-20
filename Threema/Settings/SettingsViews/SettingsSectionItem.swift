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
import ThreemaFramework

// MARK: - SettingsView.SectionItem

extension SettingsView {
    struct SectionItem<
        SettingsLabel: SettingsListItemProtocol,
        ViewDestination: ViewDestinationRepresentable
    >: SectionItemProtocol, View {
        typealias Label = SettingsLabel
        typealias Destination = AnyView
        typealias ObservableEnvironment = SettingsStore
        typealias SectionViewDestination = ViewDestination
        
        @EnvironmentObject var environmentObject: ObservableEnvironment
      
        var action: (() -> Void)?
        var destination: Destination?
        var viewDestination: ViewDestination?
        var label: Label
        var locked: Bool
        
        var body: some View {
            makeItemView()
        }
    }
}

extension SettingsView.SectionItem {
    
    init(
        locked: Bool = false,
        viewDestination: ViewDestination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.locked = locked
        self.viewDestination = viewDestination
        self.label = label()
    }
}

extension SettingsView.SectionItem where ViewDestination == EmptyViewDestination {
    
    typealias Fn<T> = () -> T
    
    init(
        locked: Bool = false,
        destination: @autoclosure @escaping Fn<AnyView?> = nil,
        action: Fn<Void>? = nil,
        title: String,
        image: ThreemaImageResource
    ) where Label == SettingsListItemView {
        self.destination = destination()
        self.action = action
        self.locked = locked
        self.label = SettingsListItemView(cellTitle: title, accessoryText: nil, image: image)
    }
    
    init(
        locked: Bool = false,
        action: Fn<Void>? = nil,
        @ViewBuilder label: @escaping Fn<Label>
    ) {
        self.action = action
        self.locked = locked
        self.label = label()
    }
    
    init(
        locked: Bool = false,
        destination: (() -> some View)? = nil,
        @ViewBuilder label: @escaping Fn<Label>
    ) {
        self.locked = locked
        self.destination = destination?().asAnyView
        self.label = label()
    }
    
    init(
        locked: Bool = false,
        @ViewBuilder destination: @escaping () -> some View,
        title: String,
        accessoryText: String? = nil,
        image: ThreemaImageResource
    ) where Label == SettingsListItemView {
        self.init(locked: locked, destination: destination) {
            SettingsListItemView(cellTitle: title, accessoryText: accessoryText, image: image)
        }
    }
    
    init(
        action: @escaping Fn<Void>,
        title: String,
        image: ThreemaImageResource,
        locked: Bool = false
    ) where Label == SettingsListItemView {
        self.init(locked: locked, action: action) {
            SettingsListItemView(cellTitle: title, accessoryText: nil, image: image)
        }
    }
}
