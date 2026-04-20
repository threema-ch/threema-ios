import Combine
import Observation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

@MainActor
@Observable
final class BackupsViewModel {

    // MARK: - Public types

    enum Route {
        case threemaSafe
        case idExport
    }

    // MARK: - Public Properties

    let screenTitle = #localize("backups")
    let idExportButtonTitle = #localize("profile_id_export")

    var isIDExportDisabled = false
    var safeIsDisabled = false

    var idExportSectionFooter: String {
        if isIDExportDisabled {
            #localize("disabled_by_device_policy_feature")
        }
        else {
            #localize("restore_option_id")
        }
    }

    var safeSectionFooter: String {
        if safeIsDisabled {
            #localize("disabled_by_device_policy_feature")
        }
        else {
            #localize("safe_setup_backup_section_footer")
        }
    }

    var safeButtonTitle: String {
        .localizedStringWithFormat(
            #localize("safe_setup_backup_title"), appFlavor.localizedAppName
        )
    }

    var safeActivationStatusLabel: String {
        isActivated ? #localize("On") : #localize("Off")
    }

    @ObservationIgnored
    var routePublisher = PassthroughSubject<Route, Never>()

    // MARK: - Public properties

    private let appFlavor: any AppFlavorServiceProtocol
    private let mdmSetup: any MDMSetupProtocol
    private let safeManager: SafeManagerProtocol
    private var isActivated = false

    // MARK: - Public lifecycle

    init(
        appFlavor: any AppFlavorServiceProtocol,
        mdmSetup: MDMSetupProtocol,
        safeManager: SafeManagerProtocol
    ) {
        self.appFlavor = appFlavor
        self.mdmSetup = mdmSetup
        self.safeManager = safeManager
    }

    // MARK: - Public methods

    func onAppear() {
        refresh()
    }

    func safeButtonTapped() {
        routePublisher.send(.threemaSafe)
    }

    func idExportButtonTapped() {
        routePublisher.send(.idExport)
    }

    // MARK: - Private methods

    private func refresh() {
        safeIsDisabled = mdmSetup.isSafeBackupDisable()
        isIDExportDisabled = mdmSetup.disableIDExport()
        isActivated = safeManager.isActivated
    }
}
