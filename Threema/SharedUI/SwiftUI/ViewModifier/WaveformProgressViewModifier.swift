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
import ThreemaFramework

struct WaveformProgressViewModifier: ViewModifier {
    @Binding var progress: CGFloat
    @State private var isDragging = false
    
    var onSeek: (Double) -> Void
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .maskedWaveForm(progress: progress, primary: .accentColor, secondary: .gray)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newProgress = max(0, min(value.location.x / geometry.size.width, 1.0))
                            onSeek(newProgress)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .gesture(
                    // TapGesture
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let newProgress = max(0, min(value.location.x / geometry.size.width, 1.0))
                            onSeek(newProgress)
                        }
                )
                .animation(.default, value: isDragging)
        }
    }
}

extension View {
    /// Add drag and tap gestures plus the masking for the waveform.
    ///
    /// - Parameters:
    ///   - progress: A binding to the progress value, represented as a CGFloat between 0 and 1.
    ///   - onSeek: forwards the seek back.
    /// - Returns: A view modified with a waveform progress view modifier.
    func waveformProgress(progress: Binding<CGFloat>, onSeek: @escaping (Double) -> Void) -> some View {
        modifier(WaveformProgressViewModifier(progress: progress, onSeek: onSeek))
    }
}
