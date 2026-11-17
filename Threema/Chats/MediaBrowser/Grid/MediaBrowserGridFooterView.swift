import UIKit

/// Number of media at the end of the media grid, styled like the footer of the contact list
final class MediaBrowserGridFooterView: UICollectionReusableView {

    private enum Configuration {
        static let topInset: CGFloat = 10
    }

    var text: String? {
        didSet {
            label.text = text
        }
    }

    private lazy var label: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: Configuration.topInset),
            // The safe area of the grid already keeps the label away from the bottom
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
