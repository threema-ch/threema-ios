import UIKit

/// Month of a section in the media grid, pinned to the top while scrolling
final class MediaBrowserGridSectionHeaderView: UICollectionReusableView {

    private enum Configuration {
        static let insets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    }

    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }

    // MARK: - Subviews

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.leadingAnchor,
                constant: Configuration.insets.leading
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -Configuration.insets.trailing
            ),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Configuration.insets.top),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Configuration.insets.bottom),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
