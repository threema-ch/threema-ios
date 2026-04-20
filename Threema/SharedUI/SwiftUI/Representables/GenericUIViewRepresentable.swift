import SwiftUI
import ThreemaFramework

extension UIView {
    @available(*, deprecated, message: "Do not use anymore.")
    struct WrapperView<V: UIView>: UIViewRepresentable {
        typealias CreateView = () -> V
        
        private let makeUIView: CreateView
        
        init(makeUIView: @escaping CreateView) {
            self.makeUIView = makeUIView
        }
        
        func makeUIView(context: Context) -> V {
            makeUIView()
        }
        
        func updateUIView(_ uiView: V, context: Context) { }
    }
    
    @available(*, deprecated, message: "Do not use anymore.")
    struct SelfSizingWrappedView: View {
        @State private var targetSize: CGSize = .zero
        
        let content: () -> UIView

        var body: some View {
            ZStack {
                Color.clear
                    .readSize {
                        targetSize = $0
                    }
                
                sizedView
            }
        }
        
        private var sizedView: some View {
            let viewContent = content()
            viewContent.layoutIfNeeded()
            let size = viewContent.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            return viewContent
                .wrappedView
                .frame(
                    width: size.width,
                    height: size.height
                )
        }
    }
    
    var selfSizingWrappedView: some View {
        SelfSizingWrappedView { self }
    }
    
    var wrappedView: some View {
        WrapperView { self }
    }
}
