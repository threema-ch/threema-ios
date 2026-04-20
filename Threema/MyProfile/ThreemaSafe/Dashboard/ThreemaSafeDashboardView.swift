import SwiftUI
import ThreemaFramework

struct ThreemaSafeDashboardView: View {

    @Bindable var model: ThreemaSafeDashboardViewModel

    var body: some View {
        VStack {
            if model.isActivated {
                ThreemaSafeActivatedView(model: model)
            }
            else {
                ThreemaSafeDeactivatedView(model: model)
            }
        }
        .disabled(model.isLoading)
        .navigationTitle(model.screenTitle)
        .onAppear {
            model.onAppear()
        }
        .onDisappear {
            model.onDisappear()
        }
        .sheet(item: $model.destination) { destination in
            switch destination {
            case let .updatePassword(model):
                NavigationView {
                    ThreemaSafePasswordView(model: model)
                }

            case let .learnMore(model):
                NavigationView {
                    ThreemaSafeLearnMoreView(model: model)
                }
            }
        }
    }

    struct ThreemaSafeActivatedView: View {

        @Bindable var model: ThreemaSafeDashboardViewModel

        var body: some View {
            List {
                ServerSection(model: model)
                BackupSection(model: model)
                ActionsSection(model: model)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: model.learnMoreButtonTapped) {
                        Image(systemName: model.infoIcon)
                    }
                }
            }
            .alert(item: $model.alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message))
            }
            .confirmationDialog(
                model.turnOffActionTitle,
                isPresented: $model.showsConfirmationDialog,
                titleVisibility: .visible,
                actions: {
                    Button(model.deactivateActionTitle, role: .destructive) {
                        model.deactivateActionConfirmed()
                    }
                }, message: {
                    Text(model.confirmationMessage)
                }
            )
        }

        struct ServerSection: View {
            let model: ThreemaSafeDashboardViewModel

            var body: some View {
                Section {
                    HStack {
                        Text(model.serverNameLabel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(model.serverNameValue)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(model.serverNameLabel)
                    .accessibilityValue(model.serverNameValue)

                    HStack {
                        Text(model.maxBackupBytesLabel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(model.maxBackupBytesValue)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(model.maxBackupBytesLabel)
                    .accessibilityValue(model.maxBackupBytesValue)

                    HStack {
                        Text(model.storageDurationLabel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(model.storageDurationValue)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(model.storageDurationLabel)
                    .accessibilityValue(model.storageDurationValue)

                } header: {
                    Text(model.serverSectionHeader)
                }
            }
        }

        struct BackupSection: View {
            @Environment(\.dynamicTypeSize) var dynamicTypeSize
            @ScaledMetric var dynamicSpacing: CGFloat = 6

            let model: ThreemaSafeDashboardViewModel

            var body: some View {
                Section {
                    HStack {
                        Text(model.backupStatusLabel)
                            .foregroundStyle(.primary)
                        Spacer()

                        if model.isLoading {
                            ProgressView()
                        }
                        else {
                            switch model.backupStatusValue {
                            case .undetermined:
                                Text(model.backupStatusValue.message)
                                    .foregroundStyle(.secondary)

                            case .succeeded:
                                Image(systemName: model.successIcon)
                                    .foregroundStyle(Color.green)

                            case .failed:
                                Button {
                                    model.backupStatusRowTapped()
                                } label: {
                                    HStack {
                                        Spacer()
                                        Image(systemName: model.infoIcon)
                                            .foregroundStyle(Color.accentColor)
                                        Image(systemName: model.errorIcon)
                                            .foregroundStyle(Color.red)
                                    }
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityRemoveTraits(.isSelected)
                    .accessibilityLabel(model.backupStatusLabel)
                    .accessibilityValue(model.backupStatusValue.message)

                    HStack {
                        Text(model.backupDateLabel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(model.backupDateValue)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(model.backupDateLabel)
                    .accessibilityValue(model.backupDateValue)

                    HStack {
                        Text(model.backupSizeLabel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(model.backupSizeValue)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(model.backupSizeLabel)
                    .accessibilityValue(model.backupSizeValue)

                } header: {
                    Text(model.backupSectionHeader)
                }
            }
        }

        struct ActionsSection: View {
            let model: ThreemaSafeDashboardViewModel

            var body: some View {
                Section {
                    Button {
                        model.createBackupButtonTapped()
                    } label: {
                        Text(model.backupButtonTitle)
                    }
                    .foregroundStyle(Color.accentColor)

                    Button {
                        model.changePasswordButtonTapped()
                    } label: {
                        Text(model.changePasswordButtonTitle)
                    }
                    .foregroundStyle(model.isChangePasswordDisabled ? Color.secondary : Color.accentColor)
                    .disabled(model.isChangePasswordDisabled)
                }

                Section {
                    Button(role: .destructive) {
                        model.deactivateButtonTapped()
                    } label: {
                        Text(model.deactivateButtonTitle)
                    }
                    .disabled(model.isDeactivationDisabled)
                } footer: {
                    if model.isDeactivationDisabled {
                        Text(model.deactivateSectionFooter)
                    }
                }
            }
        }
    }

    struct ThreemaSafeDeactivatedView: View {

        let model: ThreemaSafeDashboardViewModel

        var body: some View {
            List {
                Section {
                    VStack {
                        Image(model.threemaSafeIcon)
                            .resizable()
                            .frame(width: 128, height: 128)
                            .scaledToFit()
                            .clipShape(.circle)
                            .padding(.bottom)
                            .accessibilityHidden(true)

                        Text({
                            var attributedString = AttributedString(model.threemaSafeDescription + " ")
                            var linkText = AttributedString(model.learnMoreButtonTitle + "…")
                            linkText.link = URL.temporaryDirectory
                            linkText.foregroundColor = .accentColor
                            attributedString.append(linkText)
                            return attributedString
                        }())
                            .multilineTextAlignment(.center)
                            .font(.body)
                            .accessibilityAddTraits(.isButton)
                    }
                    .listRowInsets(EdgeInsets(top: 32, leading: 16, bottom: 32, trailing: 16))
                    .frame(maxWidth: .infinity)
                }

                Section {
                    Button {
                        model.activateButtonTapped()
                    } label: {
                        Text(model.activateButtonTitle)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .environment(\.openURL, OpenURLAction { _ in
                model.learnMoreButtonTapped()
                return .handled
            })
        }
    }
}

#if DEBUG

    #Preview("Activated (Backup succeeded)") {
        NavigationView {
            ThreemaSafeDashboardView(
                model: .init(
                    appFlavor: .mock,
                    myIdentityStore: .mock,
                    mdmSetup: .mock,
                    notificationCenter: .mock,
                    safeConfigManager: .backupSucceeded,
                    safeManager: .activated,
                    safeStore: .mock
                )
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    #Preview("Activated (Backup failed)") {
        NavigationView {
            ThreemaSafeDashboardView(
                model: .init(
                    appFlavor: .mock,
                    myIdentityStore: .mock,
                    mdmSetup: .mock,
                    notificationCenter: .mock,
                    safeConfigManager: .backupFailed,
                    safeManager: .activated,
                    safeStore: .mock
                )
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    #Preview("Activated (Backup in progress)") {
        let model = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .activated,
            safeStore: .mock
        )
        model.isLoading = true

        return NavigationView {
            ThreemaSafeDashboardView(model: model)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    #Preview("Deactivated") {
        NavigationView {
            ThreemaSafeDashboardView(
                model: .init(
                    appFlavor: .mock,
                    myIdentityStore: .mock,
                    mdmSetup: .mock,
                    notificationCenter: .mock,
                    safeConfigManager: .backupSucceeded,
                    safeManager: .deactivated,
                    safeStore: .mock
                )
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    #Preview("Deactivate Threema Safe Disabled (MDM)") {
        NavigationView {
            ThreemaSafeDashboardView(
                model: ThreemaSafeDashboardViewModel(
                    appFlavor: .mock,
                    myIdentityStore: .mock,
                    mdmSetup: .safeForced,
                    notificationCenter: .mock,
                    safeConfigManager: .mock,
                    safeManager: .activated,
                    safeStore: .mock
                )
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    #Preview("Change Password Disabled") {
        NavigationView {
            ThreemaSafeDashboardView(
                model: ThreemaSafeDashboardViewModel(
                    appFlavor: .mock,
                    myIdentityStore: .mock,
                    mdmSetup: .safePasswordPreset,
                    notificationCenter: .mock,
                    safeConfigManager: {
                        var m = MockSafeConfigManager()
                        m.mockGetKey = [1, 2, 3]
                        return m
                    }(),
                    safeManager: .mock,
                    safeStore: {
                        let m = MockSafeStore()
                        m.createdKey = [1, 2, 3]
                        return m
                    }()
                )
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

#endif
