import UIKit

extension UILabel {
    /// Returns true if the label's text would exceed `maxLines` lines at the given width.
    /// Safe to call before layout — does not depend on the label's frame.
    func exceeds(lines maxLines: Int, availableWidth: CGFloat) -> Bool {
        guard let text, let font else {
            return false
        }
        
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        
        // Convert back to a line count and round to the nearest integer.
        // boundingRect can accumulate per-line pixel-snapping errors (up to
        // 1/scale pt per line) that push the raw height fractionally above
        // maxLines × lineHeight and produce a false positive. Rounding absorbs
        // that noise without masking genuine overflow — a real extra line adds a
        // full lineHeight, so it always rounds up correctly.
        let measuredLines = (measured.height / font.lineHeight).rounded(.toNearestOrAwayFromZero)
        return Int(measuredLines) > maxLines
    }
}
