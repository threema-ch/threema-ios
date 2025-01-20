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

import DSWaveformImage
import SwiftUI

struct ProgressViewWaveform: View {
    @EnvironmentObject var model: VoiceMessageRecorderView.Model
    @State private var progress = 0.0
    
    private var drawer = WaveformImageDrawer()
    private var renderer = LinearWaveformRenderer()
    
    var body: some View {
        waveformView
            .onChange(of: model.duration) { duration in
                Task(priority: .userInitiated) {
                    progress = await duration / (model.voiceMessageManager.tmpAudioDuration)
                }
            }
    }
    
    private var waveformView: some View {
        GeometryReader { geometry in
            let modified = model.configuration.with(size: geometry.size)
            let length = Int(modified.size.width * modified.scale)
            let waveform = drawer.waveformImage(
                from: interpolatedSamples(
                    samples: model.samples,
                    toLength: length
                ),
                with: modified,
                renderer: renderer
            )
            
            if let waveform {
                Image(uiImage: waveform)
                    .waveformProgress(progress: .constant(progress)) { progress in
                        model.seek(to: progress)
                    }
            }
            else {
                EmptyView()
            }
        }
    }
}

extension ProgressViewWaveform {
    /// Interpolates the given samples to a new length.
    /// - Parameters:
    ///   - samples: An array of `Float` representing the original samples.
    ///   - toLength: The new length to which the samples should be interpolated.
    /// - Returns: An array of `Float` containing the interpolated samples.
    private func interpolatedSamples(samples: [Float], toLength newLength: Int) -> [Float] {
        guard newLength > 0, newLength < samples.count else {
            return if newLength == 0 {
                samples
            }
            else {
                // fill the empty space, if the array is not large enough
                samples + (0..<(newLength - samples.count)).map { _ in 1.0 }
            }
        }
        
        let result = UnsafeMutableBufferPointer<Float>.allocate(capacity: newLength)
        defer { result.deallocate() }
        
        samples.withUnsafeBufferPointer { buffer in
            let compressionRatio = Float(buffer.count) / Float(newLength)
            
            for i in 0..<newLength {
                let position = compressionRatio * Float(i)
                let leftIndex = Int(position)
                let rightIndex = min(leftIndex + 1, buffer.count - 1)
                let t = position - Float(leftIndex)
                let interpolatedValue = (1 - t) * buffer[leftIndex] + t * buffer[rightIndex]
                result[i] = interpolatedValue
            }
        }
    
        return Array(result)
    }
}
