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

struct ContentFadeModifier: ViewModifier {
    var leadingColor: Color = .white
    var trailingColor: Color = .clear
    var fadeLength: CGFloat = 5

    func body(content: Content) -> some View {
        content
            .mask {
                HStack {
                    LinearGradient(
                        gradient: Gradient(colors: [leadingColor, trailingColor]),
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                    .frame(width: fadeLength)
                    VStack { }
                    Color.white
                    VStack { }
                    LinearGradient(
                        gradient: Gradient(colors: [leadingColor, trailingColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: fadeLength)
                }
                .frame(maxWidth: .infinity)
            }
    }
}

extension View {
    func horizontalFadeOut(
        leadingColor: Color = .white,
        trailingColor: Color = .clear,
        fadeLength: CGFloat = 5
    ) -> some View {
        modifier(ContentFadeModifier(leadingColor: leadingColor, trailingColor: trailingColor, fadeLength: fadeLength))
    }
}
