import SwiftUI

@available(*, deprecated, message: "Do not use anymore.")
struct ReadSizeViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(GeometryReader { geometryProxy in
            Color.clear.preference(key: SizePreferenceKey.self, value: geometryProxy.size)
        })
    }
}

extension View {
    @available(*, deprecated, message: "Do not use anymore.")
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        modifier(ReadSizeViewModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

@available(*, deprecated, message: "Do not use anymore.")
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func disableDragGesture() -> some View {
        highPriorityGesture(DragGesture().onChanged { _ in })
    }
}
