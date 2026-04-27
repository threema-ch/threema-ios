import Foundation
import UIKit

/// Configuration constants for chat text view
public enum ChatTextViewConfiguration {
    public static let borderWidth = 0.5
    public static let cornerRadius =
        if #available(iOS 26.0, *) {
            20.0
        }
        else {
            16.5
        }

    public static let smallerContentSizeConfigurationCornerRadius =
        if #available(iOS 26.0, *) {
            18.5
        }
        else {
            15.5
        }

    public static let leadingAndTrailingInset: CGFloat =
        if #available(iOS 26.0, *) {
            12
        }
        else {
            10
        }

    // Ideally they fulfill cornerRadius > 2*minTopAndBottomInset + TextView height with one line of text with
    // default dynamic type
    public static let minTopAndBottomInset: CGFloat =
        if #available(iOS 26.0, *) {
            8.0
        }
        else {
            4.0
        }

    // To center the initial line correctly in the text view (with the Y-centered placeholder) we need to adjust
    // the top inset a little bit
    public static let topInsetOffset: CGFloat =
        if #available(iOS 26.0, *) {
            1.0
        }
        else {
            0.5
        }

    public static let textStyle = UIFont.TextStyle.body
}
