import Foundation
import ThreemaMacros

final class DeletedMessageView: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    private func configureLabel() {
        numberOfLines = 0

        font = ChatViewConfiguration.Text.font.italic()
        textColor = .secondaryLabel
        adjustsFontForContentSizeCategory = true

        lineBreakMode = .byWordWrapping

        text = #localize("deleted_message")
    }
}
