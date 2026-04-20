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
