import SwiftUI

struct LaunchModalSettingsView: View {
    @State var showThreemaSafeIntroView = false
    @State var showNotificationReminderView = false
    @State var showNotificationTypeSelectionView = false
    @State var showIdentityThisDeviceOnlyDecisionView = false
    @State var showRemoteSecretActivateView = false
    @State var showRemoteSecretDeactivateView = false
    @State var showFeedBackView = false

    var body: some View {
        List {
            Section {
                Button {
                    showNotificationReminderView.toggle()
                } label: {
                    Text(verbatim: "Notification Reminder")
                }
                .sheet(isPresented: $showNotificationReminderView) {
                    NotificationReminderView {
                        // no-op
                    }
                }
                
                Button {
                    showNotificationTypeSelectionView.toggle()
                } label: {
                    Text(verbatim: "Notification Type Selection")
                }
                .sheet(isPresented: $showNotificationTypeSelectionView) {
                    NotificationTypeSelectionView {
                        // no-op
                    }
                }

                Button {
                    showThreemaSafeIntroView.toggle()
                } label: {
                    Text(verbatim: "Threema Safe Intro")
                }
                .sheet(isPresented: $showThreemaSafeIntroView) {
                    ThreemaSafeIntroView(
                        model: ThreemaSafeIntroViewModel(
                            appFlavor: AppFlavorService(),
                            userSettings: UserSettings.shared()
                        )
                    )
                }
                Button {
                    showRemoteSecretActivateView.toggle()
                } label: {
                    Text(verbatim: "Remote Secret Activate")
                }
                .sheet(isPresented: $showRemoteSecretActivateView) {
                    RemoteSecretActivateDeactivateView(
                        viewModel: RemoteSecretActivateDeactivateViewModel(
                            type: RemoteSecretActivateDeactivateViewModel.ViewType.activate
                        ) {
                            // no-op
                        }
                    )
                }

                Button {
                    showRemoteSecretDeactivateView.toggle()
                } label: {
                    Text(verbatim: "Remote Secret Deactivate")
                }
                .sheet(isPresented: $showRemoteSecretDeactivateView) {
                    RemoteSecretActivateDeactivateView(
                        viewModel: RemoteSecretActivateDeactivateViewModel(
                            type: RemoteSecretActivateDeactivateViewModel.ViewType.deactivate
                        ) {
                            // no-op
                        }
                    )
                }
                
                Button {
                    showIdentityThisDeviceOnlyDecisionView.toggle()
                } label: {
                    Text(verbatim: "Identity This Device Only")
                }
                .sheet(isPresented: $showIdentityThisDeviceOnlyDecisionView) {
                    IdentityThisDeviceOnlyDecisionView(businessInjector: BusinessInjector.ui) {
                        // no-op
                    }
                }
            } header: {
                Text(verbatim: "Show Modals")
            }
            
            Section {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                    NotificationPresenterWrapper.shared.present(type: .generalSuccess)
                } label: {
                    Text(verbatim: "Notification Type Selection")
                }
                
                Button(role: .destructive) {
                    resetSafeIntroShown()
                    NotificationPresenterWrapper.shared.present(type: .generalSuccess)
                } label: {
                    Text(verbatim: "Threema Safe Intro")
                }
                
                Button(role: .destructive) {
                    resetThisDeviceOnly()
                    NotificationPresenterWrapper.shared.present(type: .generalSuccess)
                } label: {
                    Text(verbatim: "This Device Only")
                }
            } header: {
                Text(verbatim: "Reset")
            }
            
            Section {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                    resetSafeIntroShown()
                    resetThisDeviceOnly()
                    NotificationPresenterWrapper.shared.present(type: .generalSuccess)
                } label: {
                    Text(verbatim: "Reset All")
                }
            }
        }
        .navigationTitle(Text(verbatim: "Launch Modals"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Private functions
    
    private func resetNotificationTypeSelection() {
        AppGroup.userDefaults().set(false, forKey: Constants.showedNotificationTypeSelectionView)
    }
    
    private func resetSafeIntroShown() {
        UserSettings.shared().safeIntroShown = false
    }
    
    private func resetThisDeviceOnly() {
        UserSettings.shared().didShowIdentityThisDeviceOnly = false
    }
}

struct LaunchModalResetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LaunchModalSettingsView()
        }
    }
}
