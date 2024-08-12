//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import ThreemaFramework

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
                Text("automatic_delete_label".localized)
                    .font(.callout)
                Spacer()
            }
            
            Picker(
                selection: $selection,
                label: Text("automatic_delete_label".localized)
            ) {
                ForEach(options) {
                    Text($0.localizedTitleDescription).tag($0)
                }.onChange(of: selection) { newValue in
                    if newValue != current, !taskIsRunning {
                        taskIsRunning = true
                        Task {
                            toBeDeleted = await model.numberOfMessagesToDelete(for: newValue.days)
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
                    Button("cancel".localized, role: .cancel) {
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
            let titleOn = "automatic_delete_on_confirmation_title".localized
            let titleOff = "automatic_delete_off_confirmation_title".localized
            return selection == .forever ? titleOff : titleOn
        }
        
        private var confirmationButtonTitle: String {
            let confirmOn = "automatic_delete_on_confirmation_button".localized
            let confirmOff = "automatic_delete_off_confirmation_button".localized
            return selection == .forever ? confirmOff : confirmOn
        }
        
        private var confirmationMessage: String? {
            guard selection != .forever else {
                return nil
            }
            
            let deleteMessage =
                if let toBeDeleted, toBeDeleted > 0 {
                    String.localizedStringWithFormat(
                        "automatic_delete_confirmation_message_immediate_deletion".localized,
                        toBeDeleted,
                        selection.localizedDescription
                    )
                }
                else {
                    String.localizedStringWithFormat(
                        "automatic_delete_confirmation_message_no_immediate_deletion".localized,
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
