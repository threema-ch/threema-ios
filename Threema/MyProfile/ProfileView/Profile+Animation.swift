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

enum AnimationState {
    case expanding
    case idleExpanded
    case idle
}

enum ImageState {
    case expanded
    case normal
}

struct TrackedFrame: Equatable {
    let id: String
    let frame: CGRect

    static func == (lhs: TrackedFrame, rhs: TrackedFrame) -> Bool {
        lhs.id == rhs.id && lhs.frame == rhs.frame
    }
}

struct ScaleRadius: AnimatableModifier {
    var rectSize: CGSize
    private var radius: CGFloat = 0
    private var scale: CGFloat = 1
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatableData(scale, radius) }
        set {
            scale = newValue.first
            radius = newValue.second
        }
    }
    
    init(isCircle: Bool, rectSize: CGSize) {
        self.rectSize = rectSize
        self.animatableData = .init(isCircle ? 0.5 : 1, isCircle ? rectSize.width / 2 : 0)
    }
    
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .scaleEffect(scale, anchor: .top)
    }
}

// MARK: - TrackedFrame + CustomDebugStringConvertible

extension TrackedFrame: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(id): \(frame)"
    }
}

// MARK: - TrackedFrame.Key

extension TrackedFrame {
    struct Key: PreferenceKey {
        typealias Value = [TrackedFrame]

        static var defaultValue: [TrackedFrame] = []

        static func reduce(value: inout [TrackedFrame], nextValue: () -> [TrackedFrame]) {
            value.append(contentsOf: nextValue())
        }
    }
}
