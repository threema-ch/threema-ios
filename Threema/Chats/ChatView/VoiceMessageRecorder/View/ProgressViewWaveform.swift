import DSWaveformImage
import SwiftUI

struct ProgressViewWaveform: View {
    @EnvironmentObject var model: VoiceMessageRecorderViewModel
    @State private var progress = 0.0
    
    private var drawer = WaveformImageDrawer()
    private var renderer = LinearWaveformRenderer()
    
    var body: some View {
        waveformView
            .onChange(of: model.duration) {
                Task {
                    progress = await model.duration / model.assetDuration
                }
            }
    }
    
    private var waveformView: some View {
        GeometryReader { geometry in
            let modified = model.waveFormConfiguration.with(size: geometry.size)
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
