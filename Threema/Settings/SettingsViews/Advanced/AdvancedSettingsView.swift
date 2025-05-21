//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjackSwift
import MBProgressHUD
import SwiftUI
import ThreemaMacros

struct AdvancedSettingsView: View {
    @EnvironmentObject var settingsVM: SettingsStore
    
    @State private var showConfirmationSheet = false
    
    #if DISABLE_SENTRY
        private let disabledSentry = true
    #else
        private let disabledSentry = false
    #endif
    
    // MARK: - View

    var body: some View {
        List {
            // MARK: Networking

            Section {
                Toggle(isOn: $settingsVM.enableIPv6) {
                    Text(#localize("settings_advanced_ipv6_title"))
                }
                .onChange(of: settingsVM.enableIPv6) { _ in
                    ServerConnector.shared().reconnect()
                }
            } header: {
                Text(#localize("settings_advanced_networking_section_header"))
            }
            
            // MARK: DebugLog

            Section {
                Toggle(isOn: $settingsVM.validationLogging) {
                    Text(#localize("settings_advanced_debug_log_title"))
                }
                .onChange(of: settingsVM.validationLogging) { newValue in
                    if newValue {
                        LogManager.addFileLogger(LogManager.debugLogFile)
                        DDLogNotice("Start logging \(ThreemaUtility.clientVersionWithMDM)")
                    }
                    else {
                        LogManager.removeFileLogger(LogManager.debugLogFile)
                    }
                }
                
                HStack {
                    Text(#localize("settings_advanced_debug_log_size_title"))
                    Spacer()
                    Text(
                        LogManager.logFileSize(LogManager.debugLogFile),
                        format: .byteCount(style: .file, spellsOutZero: false)
                    )
                    .foregroundColor(.secondary)
                }
                
                Button {
                    shareLog()
                } label: {
                    Text(#localize("settings_advanced_debug_log_share_title"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .edgesIgnoringSafeArea(.leading)
                }
                .disabled(!hasDebugLog())

                Button {
                    showDeleteDebugLogSheet()
                } label: {
                    Text(#localize("settings_advanced_debug_log_clear_log_title"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .disabled(!hasDebugLog())
                .actionSheet(isPresented: $showConfirmationSheet) {
                    ActionSheet(
                        title: Text(#localize("debug_log_clear")),
                        buttons: [
                            .destructive(Text(#localize("debug_log_clear"))) {
                                LogManager.deleteLogFile(LogManager.debugLogFile)
                                LogManager.deleteLogFile(LogManager.validationLogFile)
                                NotificationPresenterWrapper.shared.present(type: .emptyDebugLogSuccess)
                            },
                            .cancel(),
                        ]
                    )
                }
            } header: {
                Text(#localize("settings_advanced_debug_log_section_header"))
            }
            
            // MARK: Sentry

            if !disabledSentry {
                Section {
                    HStack {
                        Text("Sentry")
                        Spacer()
                        Text(settingsVM.sentryAppDevice ?? "-")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .contextMenu(ContextMenu(menuItems: {
                                Button(#localize("copy"), action: {
                                    UIPasteboard.general.string = settingsVM.sentryAppDevice ?? "-"
                                })
                            }))
                    }
                }
            }
            
            // MARK: Push notifications

            Section {
                Button {
                    reregisterPushNotifications()
                } label: {
                    Text(#localize("settings_advanced_reregister_notifications_label"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Text(#localize("settings_advanced_reregister_push_notifications_header_title"))
            } footer: {
                Text(#localize("settings_advanced_reregister_push_notifications_footer_title"))
            }
            
            // MARK: Other settings
            
            Section {
                NavigationLink {
                    CallDiagnosticViewControllerRepresentable()
                        .ignoresSafeArea(.all)
                        .navigationBarTitle("webrtc_diagnostics.title", displayMode: .inline)
                } label: {
                    Text(#localize("settings_advanced_webrtc_diagnostics_title"))
                }
                
                NavigationLink {
                    OrphanedFilesCleanupViewControllerRepresentable()
                        .ignoresSafeArea(.all)
                        .navigationBarTitle("settings_advanced_orphaned_files_cleanup", displayMode: .inline)
                } label: {
                    Text(#localize("settings_advanced_orphaned_files_cleanup"))
                }

                NavigationLink {
                    ContactsCleanupView(settingsStore: settingsVM)
                } label: {
                    Text(#localize("settings_advanced_contacts_cleanup"))
                }

                Button {
                    flushMessageQueue()
                } label: {
                    HStack {
                        Spacer()
                        Text(#localize("settings_advanced_flush_message_queue"))
                        Spacer()
                    }
                }
            } header: {
                Text(#localize("settings_advanced_other_section_header"))
            }
            
            // MARK: Safe mode Settings
            
            if SettingsBundleHelper.safeMode {
                Section {
                    Button {
                        let businessInjector = BusinessInjector(forBackgroundProcess: true)
                        businessInjector.entityManager.performAndWaitSave {

                            let batch = NSBatchUpdateRequest(entityName: "Message")
                            batch.resultType = .statusOnlyResultType
                            batch.predicate = NSPredicate(format: "read == false && isOwn == false")
                            batch.propertiesToUpdate = ["read": true]
                            if let batchResult = businessInjector.entityManager.entityFetcher.execute(batch) {
                                if let success = batchResult.result as? Bool,
                                   success {
                                    DDLogNotice("[Advanced Support Mode] Succeeded to set all unread messages to read.")
                                }
                                else {
                                    DDLogError(
                                        "[Advanced Support Mode] Failed to set all unread messages to read. ResultCount is 0"
                                    )
                                }
                            }
                            else {
                                DDLogError(
                                    "[Advanced Support Mode] Failed to set all unread messages to read. Result is nil."
                                )
                            }
                                                        
                            if let allConversations = NSSet(
                                array: businessInjector.entityManager
                                    .entityFetcher.allConversations()
                            ) as? Set<ConversationEntity> {
                                businessInjector.unreadMessages.totalCount(
                                    doCalcUnreadMessagesCountOf: allConversations,
                                    withPerformBlockAndWait: true
                                )
                                for conversation in allConversations {
                                    // print all unread messages after set all to read
                                    let unreadMessagesCount = businessInjector.entityManager.entityFetcher
                                        .countUnreadMessages(for: conversation)
                                    DDLogNotice(
                                        "[Advanced Support Mode] Conversation \(conversation.displayName) has \(unreadMessagesCount) unread messages. Unread message state on conversation is \(conversation.unreadMessageCount)"
                                    )
                                }
                            }
                        }
                        
                        NotificationManager().updateUnreadMessagesCount()
                        NotificationPresenterWrapper.shared.present(type: .resetUnreadCountSuccess)

                        let delay = DispatchTime.now() + DispatchTimeInterval.seconds(3)
                        DispatchQueue.main.asyncAfter(deadline: delay) {
                            SettingsBundleHelper.resetSafeMode()
                            exit(0)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(#localize("settings_advanced_reset_unread_count_label"))
                            Spacer()
                        }
                    }
                    
                    Button {
                        SQLDHSessionStore.deleteSessionDB()
                    } label: {
                        HStack {
                            Spacer()
                            Text(#localize("settings_advanced_reset_fs_db_label"))
                            Spacer()
                        }
                    }
                } header: {
                    Text(#localize("settings_advanced_support_settings_header_title"))
                } footer: {
                    Text(String.localizedStringWithFormat(
                        #localize("settings_advanced_support_settings_footer_title"),
                        TargetManager.localizedAppName
                    ))
                }
            }
        }
        .navigationBarTitle(#localize("settings_advanced"), displayMode: .inline)
        .tint(.accentColor)
        .onAppear {
            logMIME()
        }
    }
    
    // MARK: - Private Functions
    
    private func hasDebugLog() -> Bool {
        if let debugLogFile = LogManager.debugLogFile {
            return LogManager.logFileSize(debugLogFile) > 0
        }
        return false
    }
    
    private func showDeleteDebugLogSheet() {
        guard hasDebugLog() else {
            return
        }
        showConfirmationSheet = true
    }
    
    private func shareLog() {
        guard let debugLogFile = LogManager.debugLogFile,
              LogManager.logFileSize(debugLogFile) > 0 else {
            return
        }
        
        if let activityViewController = ActivityUtil.activityViewController(
            withActivityItems: [debugLogFile],
            applicationActivities: nil
        ),
            let currentWindow = AppDelegate.shared().currentTopViewController() {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = currentWindow.view
                activityViewController.popoverPresentationController?.sourceRect = CGRectMake(
                    currentWindow.view.bounds.maxX,
                    currentWindow.view.bounds.midY,
                    0,
                    0
                )
            }
            
            currentWindow.present(activityViewController, animated: true)
        }
    }
    
    private func reregisterPushNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
        DDLogInfo("Unregistered for remote notifications")
        MBProgressHUD.showAdded(to: AppDelegate.shared().currentTopViewController().view, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
            DDLogInfo(
                "We are still registered for notifications: \(UIApplication.shared.isRegisteredForRemoteNotifications)"
            )
            UIApplication.shared.registerForRemoteNotifications()
            DDLogInfo("Reregistered for remote notifications")
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5)) {
            MBProgressHUD.hide(for: AppDelegate.shared().currentTopViewController().view, animated: true)
            NotificationPresenterWrapper.shared.present(type: .reregisterNotificationsSuccess)
        }
    }
    
    private func flushMessageQueue() {
        settingsVM.flushMessageQueue()
    }
    
    private func logMIME() {
        let entityManager = BusinessInjector.ui.entityManager
        DDLogNotice(
            "There are \(entityManager.entityFetcher.countFileMessagesWithNoMIMEType()) file messages with no MIME type"
        )
    }
}

struct AdvancedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdvancedSettingsView()
        }
    }
}
