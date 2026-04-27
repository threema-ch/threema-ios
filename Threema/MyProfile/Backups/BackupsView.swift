import SwiftUI

struct BackupsView: View {
    let model: BackupsViewModel

    var body: some View {
        List {
            Section {
                ButtonNavigation {
                    model.safeButtonTapped()
                } label: {
                    HStack {
                        Text(model.safeButtonTitle)
                        Spacer()
                        Text(model.safeActivationStatusLabel)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier("threemaSafeButton")
                .disabled(model.safeIsDisabled)
            } footer: {
                Text(model.safeSectionFooter)
            }

            Section {
                ButtonNavigation {
                    model.idExportButtonTapped()
                } label: {
                    HStack {
                        Text(model.idExportButtonTitle)
                        Spacer()
                    }
                }
                .disabled(model.isIDExportDisabled)
            } footer: {
                Text(model.idExportSectionFooter)
            }
        }
        .navigationTitle(model.screenTitle)
        .onAppear {
            model.onAppear()
        }
    }
}

#if DEBUG
    #Preview("Safe Enabled | Activated") {
        NavigationView {
            BackupsView(
                model: BackupsViewModel(
                    appFlavor: .mock,
                    mdmSetup: .mock,
                    safeManager: .activated
                )
            )
        }
    }

    #Preview("Safe Enabled | Deactivated") {
        NavigationView {
            BackupsView(
                model: BackupsViewModel(
                    appFlavor: .mock,
                    mdmSetup: .mock,
                    safeManager: .deactivated
                )
            )
        }
    }

    #Preview("Safe Disabled") {
        NavigationView {
            BackupsView(
                model: BackupsViewModel(
                    appFlavor: .mock,
                    mdmSetup: .safeBackupDisabled,
                    safeManager: .deactivated
                )
            )
        }
    }

    #Preview("ID Export Disabled") {
        NavigationView {
            BackupsView(
                model: BackupsViewModel(
                    appFlavor: .mock,
                    mdmSetup: .idExportDisabled,
                    safeManager: .mock
                )
            )
        }
    }
#endif
