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
