import SwiftUI
import ThreemaMacros

struct CopyLabelModifier: ViewModifier {
    let value: String?
    
    func body(content: Content) -> some View {
        Menu {
            Button(action: {
                UIPasteboard.general.string = value ?? ""
            }) {
                Text(#localize("Copy"))
                Image(systemName: "doc.on.doc")
            }
        } label: {
            content
        }
    }
}

extension View {
    func copyLabel(value: String?) -> some View {
        modifier(CopyLabelModifier(value: value))
    }
}
