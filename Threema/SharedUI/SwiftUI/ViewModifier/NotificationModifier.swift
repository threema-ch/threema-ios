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

import Combine
import SwiftUI
import ThreemaFramework

struct NotificationModifier<Value>: ViewModifier {
    @Environment(\.appContainer)
    private var appContainer: AppContainer
    
    typealias NotificationKey = KeyPath<AppEnvironment, AnyNotificationPublisher<Value>>
    typealias Handler = (AnyNotificationPublisher<Value>.Output) -> Void
    
    var keyPath: NotificationKey
    var block: Handler
    
    func body(content: Content) -> some View {
        content
            .onReceive(
                appContainer.appEnvironment[keyPath: keyPath],
                perform: block
            )
    }
}

extension View {
    func onReceive<Value>(
        _ keyPath: NotificationModifier<Value>.NotificationKey,
        _ block: @escaping NotificationModifier<Value>.Handler
    ) -> some View {
        modifier(NotificationModifier(
            keyPath: keyPath,
            block: block
        ))
    }
}
