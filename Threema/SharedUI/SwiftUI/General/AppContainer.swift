//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

@dynamicMemberLookup
struct AppContainer: EnvironmentKey {
    
    let appEnvironment: AppEnvironment
 
    static var defaultValue: Self { self.default }
    
    private static let `default` =
        Self(appEnvironment: AppEnvironment(businessInjector: BusinessInjector(forBackgroundProcess: false)))
    
    subscript<T>(dynamicMember keyPath: KeyPath<AppEnvironment, T>) -> T {
        appEnvironment[keyPath: keyPath]
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<BusinessInjectorProtocol, T>) -> T {
        appEnvironment.businessInjector[keyPath: keyPath]
    }
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainer.self] }
        set { self[AppContainer.self] = newValue }
    }
}

extension View {
    func inject(_ container: AppContainer) -> some View {
        environment(\.appContainer, container)
    }
}
