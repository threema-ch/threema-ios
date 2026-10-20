import ThreemaFramework
import ThreemaMacros

@MainActor
final class ThreemaSafeLearnMoreViewModel: LearnMoreSheetModel {

    // MARK: - Public properties

    let headerIconName = "folder"
    
    var title: String {
        .localizedStringWithFormat(#localize("safe_learn_more_title"), appFlavor.localizedAppName)
    }

    var content: String {
        .localizedStringWithFormat(#localize("safe_enable_explain"), appFlavor.localizedAppName)
    }

    let doneButtonTitle = #localize("done")

    // MARK: - Private properties

    private let appFlavor: any AppFlavorServiceProtocol

    // MARK: - Lifecycle

    init(appFlavor: any AppFlavorServiceProtocol) {
        self.appFlavor = appFlavor
    }
}
