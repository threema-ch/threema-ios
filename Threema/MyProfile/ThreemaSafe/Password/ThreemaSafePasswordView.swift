import SwiftUI
import ThreemaFramework

struct ThreemaSafePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: ThreemaSafePasswordViewModel
    @FocusState private var focus: ThreemaSafePasswordViewModel.Field?

    var body: some View {
        List {
            MessageSection(model: model)
            PasswordSection(model: model, focus: $focus)
            ServerSection(model: model, focus: $focus)
        }
        .navigationTitle(model.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.shouldDismiss) {
            if model.shouldDismiss {
                dismiss()
            }
        }
        .toolbar {
            if model.isCancelButtonVisible {
                ToolbarItem(placement: .cancellationAction) {
                    CancelButton {
                        model.cancelButtonTapped()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                ConfirmationButton(title: model.rightButtonTitle) {
                    Task { await model.rightButtonTapped() }
                }
                .disabled(model.isRightButtonDisabled)
            }
        }
        .disabled(model.isLoading)
        .alert(item: $model.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(alert.dismissTitle)) {
                    focus = .password
                }
            )
        }
        .confirmationDialog(
            model.warning?.title ?? "",
            isPresented: $model.showsConfirmationDialog,
            titleVisibility: .visible,
            actions: {
                Button(model.warning?.actionTitle ?? "", role: .destructive) {
                    Task { await model.warning?.action() }
                }
                Button(model.warning?.cancelTitle ?? "", role: .cancel) {
                    Task { await model.warning?.cancel() }
                }
            }, message: {
                Text(model.warning?.message ?? "")
            }
        )
        .onAppear {
            model.onAppear()
        }
        .loadingOverlay(model.isLoading)
    }

    struct MessageSection: View {
        @Bindable var model: ThreemaSafePasswordViewModel

        var body: some View {
            if model.isMessageSectionVisible {
                Section {
                    Text(model.messageSectionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isStaticText)
                }
                .listRowBackground(Color.clear)
            }
            else {
                EmptyView()
            }
        }
    }

    struct PasswordSection: View {
        @Bindable var model: ThreemaSafePasswordViewModel
        var focus: FocusState<ThreemaSafePasswordViewModel.Field?>.Binding

        var body: some View {
            if model.isPasswordSectionVisible {
                Section {
                    SecureField(model.passwordPlaceholder, text: $model.passwordTextInput)
                        .accessibilityLabel(model.passwordPlaceholder)
                        .accessibilityValue(model.passwordTextInput)
                        .focused(focus, equals: .password)
                        .submitLabel(.next)
                        .onSubmit {
                            focus.wrappedValue = .confirmation
                        }

                    SecureField(model.confirmationPasswordPlaceholder, text: $model.confirmationPasswordTextInput)
                        .accessibilityLabel(model.confirmationPasswordPlaceholder)
                        .accessibilityValue(model.confirmationPasswordTextInput)
                        .focused(focus, equals: .confirmation)
                        .submitLabel(model.isCustomServerInputVisible ? .next : .done)
                        .onSubmit {
                            if model.isCustomServerInputVisible {
                                focus.wrappedValue = .serverAddress
                            }
                            else {
                                Task { await model.rightButtonTapped() }
                            }
                        }
                } header: {
                    Text(model.passwordSectionHeader)
                } footer: {
                    Text(model.passwordSectionFooter)
                }
                .onAppear {
                    focus.wrappedValue = .password
                }
            }
            else {
                EmptyView()
            }
        }
    }

    struct ServerSection: View {
        @Bindable var model: ThreemaSafePasswordViewModel
        var focus: FocusState<ThreemaSafePasswordViewModel.Field?>.Binding

        var body: some View {
            if model.isServerSectionVisible {
                Section {
                    Toggle(model.serverToggleLabel, isOn: $model.isDefaultServerSwitchedOn)
                        .accessibilityRemoveTraits(.isButton)
                        .accessibilityValue(model.isDefaultServerSwitchedOn.description)
                        .tint(.accentColor)

                    if model.isCustomServerInputVisible {
                        TextField(model.serverAddressPlaceholder, text: $model.serverURLInput)
                            .accessibilityLabel(model.serverAddressPlaceholder)
                            .accessibilityValue(model.serverURLInput)
                            .focused(focus, equals: .serverAddress)
                            .submitLabel(.next)
                            .onSubmit {
                                focus.wrappedValue = .serverUsername
                            }
                    }
                } header: {
                    Text(model.serverSectionHeader)
                } footer: {
                    Text(model.serverSectionFooter)
                }

                if model.isCustomServerInputVisible {
                    Section {
                        TextField(model.serverUsernamePlaceholder, text: $model.serverUsernameInput)
                            .accessibilityLabel(model.serverUsernamePlaceholder)
                            .accessibilityValue(model.serverUsernameInput)
                            .focused(focus, equals: .serverUsername)
                            .submitLabel(.next)
                            .onSubmit {
                                focus.wrappedValue = .serverPassword
                            }

                        SecureField(model.serverPasswordPlaceholder, text: $model.serverPasswordInput)
                            .accessibilityLabel(model.serverPasswordPlaceholder)
                            .accessibilityValue(model.serverPasswordInput)
                            .focused(focus, equals: .serverPassword)
                            .submitLabel(.done)
                            .onSubmit {
                                Task { await model.rightButtonTapped() }
                            }

                    } header: {
                        Text(model.serverAuthenticationHeader)
                    }
                }
            }
            else {
                EmptyView()
            }
        }
    }
}

#if DEBUG
    #Preview(Stance.noPresets.info) { Stance.noPresets.makeView() }
    #Preview(Stance.passwordPreset.info) { Stance.passwordPreset.makeView() }
    #Preview(Stance.serverPreset.info) { Stance.serverPreset.makeView() }
    #Preview(Stance.passwordAndServerPreset.info) { Stance.passwordAndServerPreset.makeView() }
    #Preview(Stance.forced.info) { Stance.forced.makeView() }
    #Preview(Stance.forcedPasswordPreset.info) { Stance.forcedPasswordPreset.makeView() }
    #Preview(Stance.forcedServerPreset.info) { Stance.forcedServerPreset.makeView() }
    #Preview(Stance.forcedPasswordAndServerPreset.info) { Stance.forcedPasswordAndServerPreset.makeView() }
    #Preview(Stance.chancePassword.info) { Stance.chancePassword.makeView() }
    #Preview(Stance.noPresetsOnPrem.info) { Stance.noPresetsOnPrem.makeView() }

    enum Stance: CaseIterable, Identifiable {
        case noPresets
        case noPresetsOnPrem
        case passwordPreset
        case serverPreset
        case passwordAndServerPreset
        case forced
        case forcedPasswordPreset
        case forcedServerPreset
        case forcedPasswordAndServerPreset
        case chancePassword

        var id: UUID { .init() }

        @MainActor var model: ThreemaSafePasswordViewModel {
            let appFlavor: AppFlavorServiceProtocol =
                switch self {
                case .noPresetsOnPrem:
                    .onPrem
                default:
                    .mock
                }

            let myIdentityStore: MyIdentityStoreProtocol = .mock
            let safeConfigManager: SafeConfigManagerProtocol = .mock

            let safeManager: SafeManagerProtocol =
                switch self {
                case .chancePassword: .activated
                default: .deactivated
                }

            let mdmSetup: MDMSetupProtocol =
                switch self {
                case .noPresets:
                    .mock
                case .noPresetsOnPrem:
                    .mock
                case .passwordPreset:
                    .safePasswordPreset
                case .serverPreset:
                    .safeServerPreset
                case .passwordAndServerPreset:
                    .safePasswordAndServerPreset
                case .forced:
                    .safeForced
                case .forcedPasswordPreset:
                    .safeForcedWithPasswordPreset
                case .forcedServerPreset:
                    .safeForcedWithServerPreset
                case .forcedPasswordAndServerPreset:
                    .safeForcedWithPasswordAndServerPreset
                case .chancePassword:
                    .mock
                }

            return .init(
                appFlavor: appFlavor,
                myIdentityStore: myIdentityStore,
                safeConfigManager: safeConfigManager,
                safeManager: safeManager,
                mdmSetup: mdmSetup
            )
        }

        var info: String {
            switch self {
            case .noPresets:
                "No presets"
            case .noPresetsOnPrem:
                "No presets OnPrem"
            case .passwordPreset:
                "Password preset"
            case .serverPreset:
                "Server preset"
            case .passwordAndServerPreset:
                "Password and Server presets"
            case .forced:
                "Forced"
            case .forcedPasswordPreset:
                "Forced, password preset"
            case .forcedServerPreset:
                "Forced, server preset"
            case .forcedPasswordAndServerPreset:
                "Forced, password and server Preset"
            case .chancePassword:
                "Changing password"
            }
        }

        @MainActor func makeView() -> some View {
            NavigationView {
                ThreemaSafePasswordView(model: model)
            }
        }
    }

#endif
