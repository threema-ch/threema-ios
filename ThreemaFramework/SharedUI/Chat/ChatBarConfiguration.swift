/// Configuration constants for chat bar
public enum ChatBarConfiguration {
    /// Size of the send button
    public static let sendButtonSize: CGFloat = 26
    /// Size of the attachment add button (plus button)
    public static let plusButtonSize: CGFloat = 21
    /// Spacing between the camera and microphone icons
    public static let cameraMicSpacing: CGFloat =
        if #available(iOS 26.0, *) {
            3.0
        }
        else {
            18.0
        }

    public static let defaultSize: CGFloat =
        if #available(iOS 26.0, *) {
            19
        }
        else {
            17
        }

    public static let buttonTrailingLeadingSpacing: CGFloat = 4
    /// Spacing between the attachment add button and the textInputView and the textInputView and the microphone /
    /// camera / send button
    public static let textInputButtonSpacing: CGFloat = 12.0
    /// Vertical distance between border of ChatBar and text view
    public static let verticalChatBarTextViewDistance: CGFloat =
        if #available(iOS 26.0, *) {
            12
        }
        else {
            7
        }

    /// The maximum number of lines before the textInputView start to scroll
    public static let maxNumberOfLinesPortrait = 7
    /// The maximum number of lines before the textInputView start to scroll for small devices
    public static let maxNumberOfLinesPortraitSmallScreen = 5
    /// The maximum number of lines before the textInputView start to scroll
    public static let maxNumberOfLinesLandscape = 3
    /// The maximum number of lines before the textInputView start to scroll for small devices
    public static let maxNumberOfLinesLandscapeSmallScreen = 1.5
    /// The default value for the height of a single line
    public static let defaultSingleLineHeight: CGFloat = 33.5
    /// The minimum spacing between the ChatBar and the top of the tableView
    public static let tableViewChatBarMinSpacing: CGFloat = 60.0
    /// Animation configuration for hiding / showing the send button
    public enum ShowHideSendButtonAnimation {
        public static let totalDuration: CGFloat = 0.25
        public static let fadeDuration: CGFloat = 0.15
        public static let preFadeDelay: CGFloat = 0.1
    }

    /// Animation shown when the ChatBar changes size
    public enum ContentInsetAnimation {
        public static let totalDuration: CGFloat = 0.25
        public static let delay: CGFloat = 0.15
    }

    public enum QuoteView {
        public static let topBottomInset: CGFloat = 8
        public static let leadingTrailingInset: CGFloat = 16
        // The spacing property of the main StackView currently used to layout the quote view and the dismiss button
        public static let stackViewSpacing: CGFloat = 16
        // Insets of the stack when using glass
        public static let glassLayoutMargins: CGFloat = 2
    }
}
