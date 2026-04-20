import SwiftUI
import ThreemaMacros

extension View {
    
    public var asAnyView: AnyView {
        AnyView(self)
    }
    
    public func apply(@ViewBuilder _ apply: (Self) -> some View) -> some View {
        apply(self)
    }
    
    public func applyIf(_ condition: Bool, apply: (Self) -> AnyView) -> AnyView {
        condition ? apply(self) : asAnyView
    }
    
    public func applyIf(_ condition: Bool, apply: (Self) -> some View) -> some View {
        condition ? apply(self).asAnyView : asAnyView
    }
}
