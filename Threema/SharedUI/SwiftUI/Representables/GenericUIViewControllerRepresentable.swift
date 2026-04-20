import SwiftUI
import ThreemaFramework

extension UIViewController {
    @available(*, deprecated, message: "Do not use anymore.")
    fileprivate struct WrapperView<V: UIViewController>: UIViewControllerRepresentable {
        typealias CreateViewController = () -> (V?)
        
        private let makeUIViewController: CreateViewController
        
        init(_ makeUIViewController: @escaping CreateViewController) {
            self.makeUIViewController = makeUIViewController
        }
 
        func makeUIViewController(context: Context) -> V {
            makeUIViewController() ?? V()
        }
        
        func updateUIViewController(_ uiViewController: V, context: Context) { }
        
        static func dismantleUIViewController(_ uiViewController: V, coordinator: ()) {
            NotificationCenter.default.removeObserver(uiViewController)
        }
    }
    
    private var wrappedView: some View {
        WrapperView { [weak self] in
            guard let self else {
                return nil
            }
            return self
        }
    }
    
    var wrappedModalNavigationView: some View {
        uiViewController(ModalNavigationController(rootViewController: self))
    }
    
    func wrappedModalNavigationView(delegate: UINavigationControllerDelegate) -> some View {
        uiViewController(
            ModalNavigationController(rootViewController: self).then {
                $0.delegate = delegate
            }
        )
    }
}

func uiViewController(_ vc: @autoclosure @escaping () -> UIViewController) -> some View {
    UIViewController.WrapperView {
        vc()
    }
}
