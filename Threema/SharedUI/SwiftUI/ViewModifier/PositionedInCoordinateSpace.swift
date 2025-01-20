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

struct PositionedInCoordinateSpace: ViewModifier {
    let targetPosition: CGPoint
    let coordinateSpace: CoordinateSpace

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            // Get the frame of the named coordinate space in global coordinates
            let targetFrame = geometry.frame(in: coordinateSpace)
            // Get the frame of the parent container in global coordinates
            let parentFrame = geometry.frame(in: .global)
            
            // Adjust for the difference between the target and parent frames
            let adjustedPosition = CGPoint(
                x: targetPosition.x - parentFrame.minX + targetFrame.minX,
                y: targetPosition.y - parentFrame.minY + targetFrame.minY
            )

            content
                .position(adjustedPosition)
        }
    }
}

extension View {
    func position(in coordinateSpace: CoordinateSpace, at point: CGPoint) -> some View {
        modifier(PositionedInCoordinateSpace(targetPosition: point, coordinateSpace: coordinateSpace))
    }
}
