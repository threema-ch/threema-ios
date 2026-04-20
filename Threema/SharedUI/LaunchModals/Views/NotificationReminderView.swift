import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct NotificationReminderView: View {
    
    @Environment(\.dismiss) var dismiss
    
    // MARK: - View

    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "exclamationmark.bubble.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.red)
                .padding(25)
            
            Text(
                String.localizedStringWithFormat(
                    #localize("push_reminder_message"),
                    TargetManager.appName,
                    TargetManager.appName,
                    TargetManager.appName
                )
            )
            .font(.title3)
            .bold()
            .multilineTextAlignment(.center)
            
            Spacer()
            Spacer()

            ThreemaButton(
                title: #localize("push_reminder_set_now"),
                style: .borderedProminent,
                size: .fullWidth
            ) {
                setReminder()
            }
            ThreemaButton(
                title: #localize("push_reminder_not_now"),
                role: .destructive,
                style: .borderless,
                size: .small
            ) {
                AppGroup.userDefaults().set(true, forKey: "PushReminderDoNotShowAgain")
                dismiss()
            }
        }
        .padding()
        .interactiveDismissDisabled()
        .onDisappear {
            // TODO: (IOS-3251) Remove
            LaunchModalManager.shared.checkLaunchModals()
        }
    }
    
    // MARK: - Private Functions

    private func setReminder() {
        guard let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString) else {
            NotificationPresenterWrapper.shared.presentError(errorText: #localize("alert_no_access_open_settings"))
            return
        }
        UIApplication.shared.open(settingsURL)
    }
}

struct NotificationReminderView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationReminderView()
    }
}
