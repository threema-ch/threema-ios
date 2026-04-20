import SwiftUI
import ThreemaMacros

struct CopyableModifier: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = true

        let interaction = UIEditMenuInteraction(delegate: context.coordinator)
        view.addInteraction(interaction)
        context.coordinator.menuInteraction = interaction

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text)
    }

    final class Coordinator: NSObject, UIEditMenuInteractionDelegate {
        var text: String
        weak var menuInteraction: UIEditMenuInteraction?

        init(text: String) {
            self.text = text
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard !UIAccessibility.isVoiceOverRunning,
                  let view = sender.view,
                  let menuInteraction else {
                return
            }

            let point = sender.location(in: view)
            let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: point)
            menuInteraction.presentEditMenu(with: config)
        }

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let copy = UIAction(title: #localize("copy"), image: UIImage(systemName: "doc.on.doc")) { [text] _ in
                UIPasteboard.general.string = text
            }
            return UIMenu(children: [copy])
        }
    }
}

extension View {
    func copyableText(_ text: String) -> some View {
        overlay(
            CopyableModifier(text: text)
                .allowsHitTesting(true)
                .contentShape(Rectangle()) // ensure hit testing over text
        )
    }
}

#Preview {
    let value = "Tap this label to copy its text to the clipboard."
    return Text(value)
        .padding()
        .foregroundStyle(.black)
        .font(.caption)
        .copyableText(value)
}
