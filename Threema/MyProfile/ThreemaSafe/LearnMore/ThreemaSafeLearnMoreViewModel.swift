import ThreemaFramework
import ThreemaMacros

@MainActor
final class ThreemaSafeLearnMoreViewModel {

    // MARK: - Public properties

    var headline: String {
        .localizedStringWithFormat(#localize("safe_learn_more_title"), appFlavor.localizedAppName)
    }

    var body: String {
        .localizedStringWithFormat(#localize("safe_enable_explain"), appFlavor.localizedAppName)
    }

    let doneButtonTitle = #localize("Done")

    // MARK: - Private properties

    private let appFlavor: any AppFlavorServiceProtocol

    // MARK: - Lifecycle

    init(appFlavor: any AppFlavorServiceProtocol) {
        self.appFlavor = appFlavor
    }
}
