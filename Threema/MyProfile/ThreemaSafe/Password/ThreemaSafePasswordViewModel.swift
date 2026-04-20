import CocoaLumberjackSwift
import Combine
import Observation
import ThreemaFramework
import ThreemaMacros

@Observable @MainActor
final class ThreemaSafePasswordViewModel {

    // MARK: - Public properties

    let cancelButtonTitle = #localize("cancel")
    let confirmationPasswordPlaceholder = #localize("password_again")
    let passwordPlaceholder = #localize("Password")
    let serverAddressPlaceholder = "https://server.example.com"
    let serverAuthenticationHeader = #localize("safe_server_authentication").uppercased()
    let serverPasswordPlaceholder = #localize("Password")
    let serverSectionHeader = #localize("safe_server_name").uppercased()
    let serverToggleLabel = #localize("safe_use_default_server")
    let serverUsernamePlaceholder = #localize("username")
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    var alert: AlertData?
    var confirmationPasswordTextInput = ""
    var isActivated = false
    var isDefaultServerSwitchedOn = true
    var isLoading = false
    var passwordTextInput = ""
    var serverURLInput = "https://"
    var serverPasswordInput = ""
    var serverUsernameInput = ""
    var shouldDismiss = false
    var showsConfirmationDialog = false

    var screenTitle: String {
        .localizedStringWithFormat(#localize("safe_setup_backup_title"), appName)
    }

    var warning: ConfirmationDialogData? {
        didSet {
            showsConfirmationDialog = warning != nil
        }
    }

    var isCancelButtonVisible: Bool {
        isNotForced
    }

    var rightButtonTitle: String {
        isActivated ? #localize("change_button_title") : #localize("activate_button_title")
    }

    var isRightButtonDisabled: Bool {
        !isPasswordManagedByAdmin && passwordFieldsAreEmpty
    }

    var isMessageSectionVisible: Bool {
        isDeactivated && isPasswordManagedByAdmin && isServerManagedByAdmin
    }

    var messageSectionText: String {
        if isForced {
            .localizedStringWithFormat(#localize("safe_configure_choose_password_mdm"), appName)
        }
        else {
            .localizedStringWithFormat(
                #localize("threema_safe_company_mdm_password_and_server_changed_title"), appName
            )
        }
    }

    var isPasswordSectionVisible: Bool {
        !isPasswordManagedByAdmin
    }

    var passwordSectionHeader: String {
        #localize("safe_configure_choose_password_title")
    }

    var passwordSectionFooter: String {
        if isPasswordManagedByAdmin {
            .localizedStringWithFormat(#localize("threema_safe_company_mdm_password_changed_title"), appName)
                + ".\n"
                + #localize("safe_change_password_disabled")
                + "."
        }
        else if isForced {
            .localizedStringWithFormat(#localize("safe_configure_choose_password_mdm"), appName)
                + "\n\n"
                + .localizedStringWithFormat(#localize("safe_configure_choose_password"), appName)
        }
        else {
            .localizedStringWithFormat(#localize("safe_configure_choose_password"), appName)
        }
    }

    var isServerSectionVisible: Bool {
        !isServerManagedByAdmin && isDeactivated
    }

    var isCustomServerInputVisible: Bool {
        !isDefaultServerSwitchedOn
    }

    var serverSectionFooter: String {
        var message = ""
        if isForced, isPasswordManagedByAdmin {
            message += .localizedStringWithFormat(#localize("safe_configure_choose_password_mdm"), appName)
        }

        if appFlavor.isOnPrem {
            message += !message.isEmpty ? "\n\n" : ""
            message += .localizedStringWithFormat(#localize("safe_configure_server_explain_onprem"), appName)
        }
        else {
            message += !message.isEmpty ? "\n\n" : ""
            message += .localizedStringWithFormat(#localize("safe_configure_server_explain"), appName)
        }
        return message
    }

    // MARK: - Private properties

    private let appFlavor: any AppFlavorServiceProtocol
    private let mdmSetup: any MDMSetupProtocol
    private let myIdentityStore: any MyIdentityStoreProtocol
    private let passwordValidator = ThreemaSafePasswordValidator()
    private let safeConfigManager: any SafeConfigManagerProtocol
    private let safeManager: any SafeManagerProtocol

    private var appName: String {
        appFlavor.localizedAppName
    }

    private var isDeactivated: Bool {
        !isActivated
    }

    private var isPasswordManagedByAdmin: Bool {
        mdmSetup.isSafeBackupPasswordPreset()
    }

    private var isServerManagedByAdmin: Bool {
        mdmSetup.isSafeBackupServerPreset()
    }

    private var isNotForced: Bool {
        !isForced
    }

    private var isForced: Bool {
        mdmSetup.isSafeBackupForce()
    }

    private var passwordFieldsAreEmpty: Bool {
        passwordTextInput.isEmpty || confirmationPasswordTextInput.isEmpty
    }

    // MARK: - Lifecycle

    init(
        appFlavor: AppFlavorServiceProtocol,
        myIdentityStore: any MyIdentityStoreProtocol,
        safeConfigManager: any SafeConfigManagerProtocol,
        safeManager: any SafeManagerProtocol,
        mdmSetup: any MDMSetupProtocol
    ) {
        self.appFlavor = appFlavor
        self.myIdentityStore = myIdentityStore
        self.safeConfigManager = safeConfigManager
        self.safeManager = safeManager
        self.mdmSetup = mdmSetup
    }

    // MARK: - Public methods

    func onAppear() {
        isActivated = safeManager.isActivated
    }

    func cancelButtonTapped() {
        shouldDismiss = true
        onCancel?()
    }

    func rightButtonTapped() async {
        var validatedServer: ServerPayload?
        switch await getServerValidationResult() {
        case let .valid(payload: payload):
            validatedServer = payload

        case let .error(title: title, message: message):
            alert = AlertData(title: title, message: message, dismissTitle: #localize("ok"))
        }

        guard let validatedServer else {
            return
        }

        var validatedPassword: String?
        switch getPasswordValidationResult() {
        case let .valid(password):
            validatedPassword = password

        case let .warning(title: title, message: message):
            showConfirmationDialog(
                title: title,
                message: message,
                password: passwordTextInput,
                serverPayload: validatedServer
            )

        case let .error(title: title, message: message):
            alert = AlertData(title: title, message: message, dismissTitle: #localize("ok"))
        }

        guard let validatedPassword else {
            return
        }

        await updateThreemaSafe(validatedPassword, validatedServer)
    }

    // MARK: - Private methods

    private func showConfirmationDialog(
        title: String,
        message: String,
        password: String,
        serverPayload: ServerPayload
    ) {
        warning = ConfirmationDialogData(
            title: title,
            message: message,
            actionTitle: #localize("continue_anyway"),
            cancelTitle: #localize("try_again")
        ) { [weak self] in
            await self?.updateThreemaSafe(password, serverPayload)
        } cancel: { [weak self] in
            self?.warning = nil
        }
    }

    private func getServerValidationResult() async -> ServerValidationResult {
        if isDefaultServerSwitchedOn, !isServerManagedByAdmin {
            return .valid(
                payload: ServerPayload(
                    customServer: nil,
                    serverUser: nil,
                    serverPassword: nil,
                    server: nil,
                    maxBackupBytes: nil,
                    retentionDays: nil
                )
            )
        }
        else {
            let url = isServerManagedByAdmin
                ? mdmSetup.safeServerURL()
                : serverURLInput

            let user = isServerManagedByAdmin
                ? mdmSetup.safeServerUsername()
                : serverUsernameInput

            let password = isServerManagedByAdmin
                ? mdmSetup.safeServerPassword()
                : serverPasswordInput

            return await testCustomServer(url, user, password)
        }
    }

    private func testCustomServer(
        _ customServerURLString: String?,
        _ customServerUser: String?,
        _ customServerPassword: String?
    ) async -> ServerValidationResult {
        do {
            guard
                let serverURLString = customServerURLString,
                let customServerURL = URL(string: serverURLString),
                customServerURL.scheme != nil,
                customServerURL.host != nil
            else {
                return .error(
                    title: #localize("safe_test_server"),
                    message: #localize("safe_test_server_invalid_url")
                )
            }
            let serverConfig = try await safeManager.testServer(
                serverURL: customServerURL,
                user: customServerUser,
                password: customServerPassword
            )
            return .valid(
                payload: ServerPayload(
                    customServer: customServerURLString,
                    serverUser: customServerUser,
                    serverPassword: customServerPassword,
                    server: customServerURLString,
                    maxBackupBytes: NSNumber(integerLiteral: serverConfig.maxBackupBytes),
                    retentionDays: NSNumber(integerLiteral: serverConfig.retentionDays)
                )
            )
        }
        catch {
            return .error(
                title: #localize("safe_test_server"),
                message: (error as? SafeApiService.SafeApiError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private func getPasswordValidationResult() -> ThreemaSafePasswordValidator.ValidationResult {
        let password = isPasswordManagedByAdmin
            ? mdmSetup.safePassword() ?? ""
            : passwordTextInput

        let passwordConfirmation = isPasswordManagedByAdmin
            ? mdmSetup.safePassword() ?? ""
            : confirmationPasswordTextInput

        let passwordResult = passwordValidator.validate(
            password: password,
            passwordConfirmation: passwordConfirmation,
            regexPattern: mdmSetup.safePasswordPattern(),
            regexErrorMessage: mdmSetup.safePasswordMessage()
        )
        return passwordResult
    }

    private func updateThreemaSafe(_ password: String, _ serverPayload: ServerPayload) async {
        isLoading = true
        defer { isLoading = false }

        if isActivated {
            safeManager.deactivate()
        }

        do {
            guard let identity = myIdentityStore.identity else {
                assertionFailure("Programming error: Identity is nil")
                struct ProgrammingError: Error { }
                throw ProgrammingError()
            }

            try await safeManager.activate(
                identity: identity,
                safePassword: password,
                customServer: serverPayload.customServer,
                serverUser: serverPayload.serverUser,
                serverPassword: serverPayload.serverPassword,
                server: serverPayload.server,
                maxBackupBytes: serverPayload.maxBackupBytes,
                retentionDays: serverPayload.retentionDays
            )

            isActivated = safeManager.isActivated
            try await safeManager.startBackup(force: true)
            shouldDismiss = true
            onFinish?()
        }
        catch {
            alert = AlertData(
                title: .localizedStringWithFormat(#localize("safe_error_preparing"), appFlavor.localizedAppName),
                message: (error as? SafeError)?.description ?? error.localizedDescription,
                dismissTitle: #localize("ok")
            )
        }
    }
}

extension ThreemaSafePasswordViewModel {
    // MARK: - Public types

    enum Field: Hashable, Equatable {
        case password
        case confirmation
        case serverAddress
        case serverUsername
        case serverPassword
    }

    struct AlertData: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let dismissTitle: String
    }

    struct ConfirmationDialogData {
        let title: String
        let message: String
        let actionTitle: String
        let cancelTitle: String
        let action: () async -> Void
        let cancel: () async -> Void
    }

    // MARK: - Private types

    private struct ServerPayload {
        let customServer: String?
        let serverUser: String?
        let serverPassword: String?
        let server: String?
        let maxBackupBytes: NSNumber?
        let retentionDays: NSNumber?
    }

    private enum ServerValidationResult {
        case valid(payload: ServerPayload)
        case error(title: String, message: String)
    }
}
