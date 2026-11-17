import Foundation
import ThreemaFramework
import UIKit

/// A settings row: icon tile, title and disclosure indicator.
///
/// Laid out by `UIListContentConfiguration`, like every other list in the app, so the rows get the system's list
/// metrics on every device (a custom constraint layout collapsed to the text height with half-size icon tiles on
/// iPhone Duo). The configuration is rebuilt in `updateConfiguration(using:)`, which UIKit calls on selection,
/// highlight and trait changes (content size category included).
final class SettingsCollectionViewCell: UICollectionViewListCell, Reusable {

    // MARK: - Properties

    var rowType: SettingsCollectionViewDataSource.Row? {
        didSet {
            setNeedsUpdateConfiguration()
        }
    }

    /// Tile edge length at the default content size; scaled with the body text style
    private static let tileSize: CGFloat = 28
    private static let tileCornerRadius: CGFloat = 5
    private static let imageToTextPadding: CGFloat = 16
    private static let symbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body, scale: .small)

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessories = [.disclosureIndicator()]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        // The configuration of the text-only rows (profile tab, network status), so all rows share its metrics
        var content = UIListContentConfiguration.valueCell().updated(for: state)
        content.text = rowType?.title
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.numberOfLines = 0

        // Accessibility sizes drop the tile, as before, to leave the width to the text.
        if state.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            content.image = nil
        }
        else {
            let tileSize = UIFontMetrics(forTextStyle: .body)
                .scaledValue(for: Self.tileSize, compatibleWith: state.traitCollection)
            content.image = Self.tileImage(for: rowType?.icon, size: tileSize, traitCollection: state.traitCollection)
            content.imageProperties.maximumSize = CGSize(width: tileSize, height: tileSize)
            // Width only: aligns the text across rows without fixing the height of the content
            content.imageProperties.reservedLayoutSize = CGSize(width: tileSize, height: 0)
            content.imageToTextPadding = Self.imageToTextPadding

            // The tile is taller than a line of text; take the difference off the default vertical margins so a
            // tile row is as high as a text-only row.
            let excess = max(0, tileSize - content.textProperties.font.lineHeight) / 2
            content.directionalLayoutMargins.top = max(0, content.directionalLayoutMargins.top - excess)
            content.directionalLayoutMargins.bottom = max(0, content.directionalLayoutMargins.bottom - excess)
        }

        contentConfiguration = content
    }

    /// The icon on a gray rounded tile, rendered for the cell's traits (display scale, content size)
    private static func tileImage(
        for icon: UIImage?,
        size: CGFloat,
        traitCollection: UITraitCollection
    ) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(
            bounds: bounds,
            format: UIGraphicsImageRendererFormat(for: traitCollection)
        )

        return renderer.image { _ in
            UIColor.gray.setFill()
            UIBezierPath(roundedRect: bounds, cornerRadius: tileCornerRadius).fill()

            guard let icon else {
                return
            }

            // Resolve the symbol against the cell's traits so its body-relative size matches the tile scale.
            traitCollection.performAsCurrent {
                let symbol = icon
                    .withConfiguration(symbolConfiguration)
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                let symbolSize = symbol.size
                let origin = CGPoint(x: (size - symbolSize.width) / 2, y: (size - symbolSize.height) / 2)
                symbol.draw(in: CGRect(origin: origin, size: symbolSize))
            }
        }
    }
}
