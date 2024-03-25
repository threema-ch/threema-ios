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

import Foundation

/// It is mainly useful for mocking `BusinessInjector` for unit tests.
protocol FrameworkInjectorResolverProtocol {
    var backgroundFrameworkInjector: FrameworkInjectorProtocol { get }
}

final class FrameworkInjectorResolver: FrameworkInjectorResolverProtocol {
    private let entityManager: EntityManager?

    init(backgroundEntityManager: EntityManager?) {
        assert(
            backgroundEntityManager?.hasBackgroundChildContext ?? true,
            "Must be an EntityManager for a background thread"
        )

        self.entityManager = backgroundEntityManager
    }

    /// Get new `BusinessInjector` for background processing (new `EntityManager` with new child context)
    /// or use `EntityManager` which is applied in the initializer (e.g. from Notification Extension).
    var backgroundFrameworkInjector: FrameworkInjectorProtocol {
        if let entityManager {
            return BusinessInjector(entityManager: entityManager)
        }
        return BusinessInjector(forBackgroundProcess: true)
    }
}
