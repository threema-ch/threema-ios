import SwiftUI

struct OnScrollModifier: ViewModifier {
    typealias DragAction = (DragGesture.Value) -> Void
    var onScroll: DragAction?
    var onEndScroll: DragAction?
    
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged(onScroll ?? { _ in })
                .onEnded(onEndScroll ?? { _ in })
        )
    }
}

extension View {
    func onScroll(
        _ onScroll: OnScrollModifier.DragAction? = nil,
        _ onEndScroll: OnScrollModifier.DragAction? = nil
    ) -> some View {
        modifier(OnScrollModifier(onScroll: onScroll, onEndScroll: onEndScroll))
    }
}
