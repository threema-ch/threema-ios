import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

final class CopyLabel: UILabel, UIEditMenuInteractionDelegate {

    // MARK: - Public properties

    var textForCopying: String?

    // MARK: - Private properties

    private var menuInteraction: UIEditMenuInteraction?

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        attachTapHandler()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        attachTapHandler()
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(copy(_:))
    }

    // MARK: - Private Methods

    private func attachTapHandler() {
        let interaction = UIEditMenuInteraction(delegate: self)
        addInteraction(interaction)
        menuInteraction = interaction
        isUserInteractionEnabled = true
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(recognizer)
    }

    @objc private func handleTap(_ sender: UIGestureRecognizer) {
        guard superview != nil else {
            DDLogError("Could not handle tap because superview was nil")
            return
        }
        guard !UIAccessibility.isVoiceOverRunning, let menuInteraction else {
            return
        }
        let location = sender.location(in: self)
        let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
        menuInteraction.presentEditMenu(with: config)
    }

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        let copy = UIAction(
            title: #localize("copy"),
            image: UIImage(systemName: "doc.on.doc")
        ) { [textForCopying, text] _ in
            UIPasteboard.general.string = textForCopying ?? text
        }
        return UIMenu(children: [copy])
    }
}

import SwiftUI

struct CopyLabelPreviews: UIViewRepresentable {

    var value: String

    func makeUIView(context: Context) -> UILabel {
        let label = CopyLabel()
        label.text = value
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.numberOfLines = 0
        label.textForCopying = value
        return label
    }

    func updateUIView(_ view: UILabel, context: Context) { /* no-op */ }
}

#Preview {
    ScrollView {
        CopyLabelPreviews(
            value: "Tap this label to copy its text to the clipboard."
        )
        .padding()
    }
}
