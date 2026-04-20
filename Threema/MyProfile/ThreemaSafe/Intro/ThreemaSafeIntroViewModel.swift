import Observation
import ThreemaFramework
import ThreemaMacros
import ThreemaProtocols

@Observable @MainActor
final class ThreemaSafeIntroViewModel {

    // MARK: - Public properties

    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?
    var shouldDismiss = false

    var title: String {
        .localizedStringWithFormat(#localize("safe_intro_title"), appFlavor.localizedAppName)
    }

    var description: String {
        .localizedStringWithFormat(#localize("safe_intro_description"), appFlavor.localizedAppName)
    }

    var explain: String {
        .localizedStringWithFormat(#localize("safe_intro_explain"), appFlavor.localizedAppName, appFlavor.appName)
    }

    let enableButtonTitle = #localize("safe_intro_enable")
    let cancelButtonTitle = #localize("safe_intro_cancel")
    let threemaSafeIcon = ImageResource(name: "ThreemaSafeIntro", bundle: .main)

    // MARK: - Private lifecycle

    private let appFlavor: any AppFlavorServiceProtocol
    private let userSettings: any UserSettingsProtocol

    // MARK: - Public lifecycle

    init(appFlavor: any AppFlavorServiceProtocol, userSettings: any UserSettingsProtocol) {
        self.appFlavor = appFlavor
        self.userSettings = userSettings
    }

    // MARK: - Public methods

    func onAppear() {
        userSettings.safeIntroShown = true
    }

    func confirmationButtonTapped() {
        shouldDismiss = true
        onConfirm?()
    }

    func cancelButtonTapped() {
        shouldDismiss = true
        onCancel?()
    }
}
