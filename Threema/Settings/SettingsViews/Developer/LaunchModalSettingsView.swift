import SwiftUI

struct LaunchModalSettingsView: View {
    @State var showThreemaSafeIntroView = false
    @State var showNotificationReminderView = false
    @State var showNotificationTypeSelectionView = false
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
                    NotificationReminderView()
                }
                
                Button {
                    showNotificationTypeSelectionView.toggle()
                } label: {
                    Text(verbatim: "Notification Type Selection")
                }
                .sheet(isPresented: $showNotificationTypeSelectionView) {
                    NotificationTypeSelectionView()
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
                        )
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
                        )
                    )
                }
            } header: {
                Text(verbatim: "Show Modals")
            }
            
            Section {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                } label: {
                    Text(verbatim: "Notification Type Selection")
                }
                
                Button(role: .destructive) {
                    resetSafeIntroShown()
                } label: {
                    Text(verbatim: "Threema Safe Intro")
                }
            } header: {
                Text(verbatim: "Reset")
            }
            
            Section {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                    resetSafeIntroShown()
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
}

struct LaunchModalResetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LaunchModalSettingsView()
        }
    }
}
