//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

/// A `ViewModifier` that masks a waveform view with a progress indicator.
/// The waveform will be displayed with two colors representing the played and remaining parts.
///
/// - Parameters:
///   - progress: representing the progress of the waveform, where 1.0 is fully played.
///   - primary: The `Color` for the played part of the waveform.
///   - secondary: The `Color` for the remaining part of the waveform.
struct MaskedWaveformModifier: ViewModifier {
    var progress: CGFloat
    var primary: Color
    var secondary: Color

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                primary
                    .frame(width: fmin(fmax(0, progress * geometry.size.width), geometry.size.width))
                secondary
                    .frame(width: fmax(0, (geometry.size.width) - (progress * geometry.size.width)))
            }
            .mask(alignment: .leading) {
                content
            }
        }
    }
}

extension View {
    /// Masks the view based on the progress
    ///
    /// - Parameters:
    ///   - progress: representing the progress of the waveform.
    ///   - primary: The `Color` for the played part of the waveform.
    ///   - secondary: The `Color` for the remaining part of the waveform.
    /// - Returns: A modified view representing the waveform with a visual progress indicator.
    func maskedWaveForm(progress: CGFloat, primary: Color, secondary: Color) -> some View {
        modifier(MaskedWaveformModifier(progress: progress, primary: primary, secondary: secondary))
    }
}
