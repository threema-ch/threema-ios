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

struct AnyViewDestination: ViewDestinationRepresentable {
    let id: UUID
    private let _view: () -> AnyView

    var view: some View {
        _view()
    }
    
    init(_ view: some View) {
        self.id = UUID()
        self._view = { view.asAnyView }
    }

    init(_ viewDestination: some ViewDestinationRepresentable) {
        self.id = UUID()
        self._view = { AnyView(viewDestination.view) }
    }

    static func == (lhs: AnyViewDestination, rhs: AnyViewDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension View {
    var anyViewDestination: AnyViewDestination {
        .init(self)
    }
}

extension ViewDestinationRepresentable {
    var anyViewDestination: AnyViewDestination {
        .init(self)
    }
}
