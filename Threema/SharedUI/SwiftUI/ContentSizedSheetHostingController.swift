import SwiftUI
import UIKit

final class ContentSizedSheetHostingController<Content: View>: UIHostingController<Content> {

    private static var fallbackHeightFraction: CGFloat { 1 / 4 }

    private(set) lazy var contentSizedDetent = UISheetPresentationController.Detent
        .custom { [weak self] context in
            guard let self else {
                return nil
            }

            guard let contentHeight else {
                return context.maximumDetentValue * Self.fallbackHeightFraction
            }

            return min(contentHeight, context.maximumDetentValue)
        }

    private var contentHeight: CGFloat?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    func contentHeightChanged(_ height: CGFloat) {
        let height = height.rounded(.up)

        guard contentHeight != height else {
            return
        }

        let isFirstMeasurement = contentHeight == nil
        contentHeight = height

        guard let sheetPresentationController else {
            return
        }

        if isFirstMeasurement {
            sheetPresentationController.invalidateDetents()
        }
        else {
            sheetPresentationController.animateChanges {
                sheetPresentationController.invalidateDetents()
            }
        }
    }
}
