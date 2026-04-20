import SwiftUI
import ThreemaFramework
import ThreemaMacros

extension StorageManagementConversationView {
    struct MessageRetentionView: View {
        @EnvironmentObject private var storageModel: StorageManagementConversationView.Model
        @Environment(\.sizeCategory) private var sizeCategory
        
        @ObservedObject var model: MessageRetentionManagerModel
        @State var selection: OlderThanOption
        
        @State private var showConfirmationDialog = false
        @State private var taskIsRunning = false
        
        @State var toBeDeleted: Int? {
            didSet {
                guard let _ = toBeDeleted else {
                    return
                }
                showConfirmationDialog = true
            }
        }
        
        private var current: OlderThanOption {
            OlderThanOption.retentionOption(from: model.selection)
        }
        
        private var options: [OlderThanOption] {
            model.isMDM ? [.custom(model.selection)] : OlderThanOption.allRetentionCases
        }
        
        var body: some View {
            if sizeCategory.isAccessibilityCategory {
                VStack {
                    picker
                }
            }
            else {
                HStack {
                    picker
                }
            }
        }
        
        @ViewBuilder
        private var picker: some View {
            HStack {
                Text(#localize("automatic_delete_label"))
                    .font(.callout)
                Spacer()
            }
            
            Picker(
                selection: $selection,
                label: Text(#localize("automatic_delete_label"))
            ) {
                ForEach(options) {
                    Text($0.localizedTitleDescription).tag($0)
                }
                .onChange(of: selection) {
                    if selection != current, !taskIsRunning {
                        taskIsRunning = true
                        Task {
                            toBeDeleted = await model.numberOfMessagesToDelete(for: selection.days)
                            taskIsRunning = false
                        }
                    }
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(model.isMDM)
            .confirmationDialog(
                confirmationDialogTitle,
                isPresented: $showConfirmationDialog,
                titleVisibility: .visible,
                actions: {
                    Button(#localize("cancel"), role: .cancel) {
                        reset()
                    }
                    Button(confirmationButtonTitle, role: selection == .forever ? nil : .destructive) {
                        confirmDeletion()
                    }
                },
                message: {
                    if let confirmationMessage {
                        Text(confirmationMessage)
                    }
                }
            )
        }
        
        private var confirmationDialogTitle: String {
            let titleOn = #localize("automatic_delete_on_confirmation_title")
            let titleOff = #localize("automatic_delete_off_confirmation_title")
            return selection == .forever ? titleOff : titleOn
        }
        
        private var confirmationButtonTitle: String {
            let confirmOn = #localize("automatic_delete_on_confirmation_button")
            let confirmOff = #localize("automatic_delete_off_confirmation_button")
            return selection == .forever ? confirmOff : confirmOn
        }
        
        private var confirmationMessage: String? {
            guard selection != .forever else {
                return nil
            }
            
            let deleteMessage =
                if let toBeDeleted, toBeDeleted > 0 {
                    String.localizedStringWithFormat(
                        #localize("automatic_delete_confirmation_message_immediate_deletion"),
                        toBeDeleted,
                        selection.localizedDescription
                    )
                }
                else {
                    String.localizedStringWithFormat(
                        #localize("automatic_delete_confirmation_message_no_immediate_deletion"),
                        selection.localizedDescription
                    )
                }
            
            return deleteMessage
        }
         
        private func reset() {
            toBeDeleted = nil
            selection = current
        }
        
        private func confirmDeletion() {
            guard let days = selection.days else {
                model.set(-1, completion: nil)
                return
            }
            
            model.set(days) {
                Task { await storageModel.load() }
                NotificationManager().updateUnreadMessagesCount()
            }
        }
    }
}
