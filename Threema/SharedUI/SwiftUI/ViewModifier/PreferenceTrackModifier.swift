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

struct PreferenceTrackModifier: ViewModifier {
    let id: String
    let coordinateSpace: CoordinateSpace?
    let data: Any?
    
    func body(content: Content) -> some View {
        content.background(
            content: {
                GeometryReader { proxy in
                    Color.clear.transformPreference(TrackedFrame.Key.self) {
                        $0.append(
                            .init(
                                id: id,
                                frame: proxy.frame(in: coordinateSpace ?? .global),
                                data: data,
                                proxy: proxy
                            )
                        )
                    }
                }
            }
        )
    }
}

extension View {
    public func trackPreference(
        _ id: String,
        coordinateSpace: CoordinateSpace? = .global,
        data: Any? = nil
    ) -> some View {
        modifier(
            PreferenceTrackModifier(
                id: id,
                coordinateSpace: coordinateSpace,
                data: data
            )
        )
    }
}
