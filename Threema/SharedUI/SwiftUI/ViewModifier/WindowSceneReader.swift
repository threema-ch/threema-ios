import SwiftUI
import UIKit

/// Reports the window scene the view is displayed in, e.g. to get the screen a SwiftUI view is shown on
private struct WindowSceneReader: UIViewRepresentable {
    let onChange: (UIWindowScene?) -> Void

    func makeUIView(context: Context) -> ReaderView {
        ReaderView(onChange: onChange)
    }

    func updateUIView(_ uiView: ReaderView, context: Context) {
        uiView.onChange = onChange
    }

    final class ReaderView: UIView {
        var onChange: (UIWindowScene?) -> Void

        init(onChange: @escaping (UIWindowScene?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            
            // This can happen during a SwiftUI view update, report it afterwards to allow state changes
            let windowScene = window?.windowScene
            DispatchQueue.main.async { [weak self] in
                self?.onChange(windowScene)
            }
        }
    }
}

extension View {
    /// Calls `action` with the window scene the view is displayed in whenever it moves to another window
    func onWindowSceneChange(_ action: @escaping (UIWindowScene?) -> Void) -> some View {
        background(WindowSceneReader(onChange: action).accessibilityHidden(true))
    }
}
