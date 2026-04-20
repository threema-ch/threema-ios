import Foundation

public struct CustomContextMenuMenuTableViewConfig {
    // Table
    let sectionSpacingHeight: CGFloat
    let sectionBackgroundColorDark: UIColor
    let sectionBackgroundColorLight: UIColor
    let tableViewBackgroundColorDark: UIColor
    let tableViewBackgroundColorLight: UIColor
    let tableViewHighlightedColor: UIColor
    let tableViewWidth: CGFloat
    let tableViewCornerRadius: CGFloat
    let tableViewInset: CGFloat
    let additionalSeparatorInset: CGFloat
    
    // Item
    let itemLeadingTrailingInset: CGFloat
    let defaultItemTopBottomInset: CGFloat
    let defaultItemTopTweak: CGFloat
    let defaultItemSpacing: CGFloat
    let defaultImageCenterInset: CGFloat
    let defaultSelectionBackgroundCornerRadius: CGFloat
    let inlineItemTopBottomInset: CGFloat
    let inlineItemCornerRadius: CGFloat
    let inlineItemSpacing: CGFloat
    let inlineItemInset: CGFloat
    let preferredTextStyle: UIFont.TextStyle
    
    // Default initializer created by compiler is enough
    
    // This tries to match the appearance on iOS 18.2
    static let defaultConfig = CustomContextMenuMenuTableViewConfig(
        sectionSpacingHeight: 8,
        sectionBackgroundColorDark: .systemBackground.withAlphaComponent(0.7),
        sectionBackgroundColorLight: .black.withAlphaComponent(0.4),
        tableViewBackgroundColorDark: .secondarySystemBackground.withAlphaComponent(0.7),
        tableViewBackgroundColorLight: .systemBackground.withAlphaComponent(0.5),
        tableViewHighlightedColor: .gray.withAlphaComponent(0.2),
        tableViewWidth: UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? 300 : 250,
        tableViewCornerRadius: 14,
        tableViewInset: 0,
        additionalSeparatorInset: 0,
        itemLeadingTrailingInset: 16,
        defaultItemTopBottomInset: 12,
        defaultItemTopTweak: -0.66,
        defaultItemSpacing: 4,
        defaultImageCenterInset: 12,
        defaultSelectionBackgroundCornerRadius: 0,
        inlineItemTopBottomInset: 8.5,
        inlineItemCornerRadius: 8,
        inlineItemSpacing: 16,
        inlineItemInset: 8,
        preferredTextStyle: .body
    )
    
    static let glassConfig = CustomContextMenuMenuTableViewConfig(
        sectionSpacingHeight: 21,
        sectionBackgroundColorDark: .separator,
        sectionBackgroundColorLight: .separator,
        tableViewBackgroundColorDark: .clear,
        tableViewBackgroundColorLight: .clear,
        tableViewHighlightedColor: .gray.withAlphaComponent(0.2),
        tableViewWidth: UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? 300 : 250,
        tableViewCornerRadius: 32,
        tableViewInset: 9,
        additionalSeparatorInset: 4,
        itemLeadingTrailingInset: 20,
        defaultItemTopBottomInset: 10.33,
        defaultItemTopTweak: 0,
        defaultItemSpacing: 13,
        defaultImageCenterInset: 15.5,
        defaultSelectionBackgroundCornerRadius: 21,
        inlineItemTopBottomInset: 0,
        inlineItemCornerRadius: 8,
        inlineItemSpacing: 4,
        inlineItemInset: 10,
        preferredTextStyle: .body
    )
}
