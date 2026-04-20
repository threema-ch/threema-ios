import SwiftUI

struct AccessibilityVStack: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    var spacing: CGFloat = 0
    
    func body(content: Content) -> some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(spacing: spacing) {
                content
            }
        }
        else {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

extension View {
    func accessibilityVStack(spacing: CGFloat) -> some View {
        modifier(AccessibilityVStack(spacing: spacing))
    }
}
