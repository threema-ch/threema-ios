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

import CocoaLumberjackSwift
import MBProgressHUD
import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var settingsVM: SettingsStore
    
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
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_ipv6_title"))
                }
                .onChange(of: settingsVM.enableIPv6) { _ in
                    ServerConnector.shared().reconnect()
                }
            } header: {
                Text(BundleUtil.localizedString(forKey: "settings_advanced_networking_section_header"))
            }
            
            // MARK: Sensor

            Section {
                Toggle(isOn: $settingsVM.disableProximityMonitoring.animation()) {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_proximity_monitoring_title"))
                }
            } header: {
                Text(BundleUtil.localizedString(forKey: "settings_advanced_proximity_monitoring_section_header"))
            } footer: {
                if settingsVM.disableProximityMonitoring {
                    Text(
                        BundleUtil.localizedString(forKey: "settings_advanced_proximity_monitoring_section_footer_off")
                    )
                }
                else {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_proximity_monitoring_section_footer_on"))
                }
            }
            
            // MARK: DebugLog

            Section {
                Toggle(isOn: $settingsVM.validationLogging) {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_debug_log_title"))
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
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_debug_log_size_title"))
                    Spacer()
                    Text(LogManager.logFileSize(LogManager.debugLogFile), format: .byteCount(style: .file))
                        .foregroundColor(.secondary)
                }
                
                Button {
                    shareLog()
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_debug_log_share_title"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .edgesIgnoringSafeArea(.leading)
                }
                .disabled(!hasDebugLog())

                Button {
                    showDeleteDebugLogSheet()
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_debug_log_clear_log_title"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .disabled(!hasDebugLog())
                .actionSheet(isPresented: $showConfirmationSheet) {
                    ActionSheet(
                        title: Text(BundleUtil.localizedString(forKey: "debug_log_clear")),
                        buttons: [
                            .destructive(Text(BundleUtil.localizedString(forKey: "debug_log_clear"))) {
                                LogManager.deleteLogFile(LogManager.debugLogFile)
                                LogManager.deleteLogFile(LogManager.validationLogFile)
                                NotificationPresenterWrapper.shared.present(type: .emptyDebugLogSuccess)
                            },
                            .cancel(),
                        ]
                    )
                }
            } header: {
                Text(BundleUtil.localizedString(forKey: "settings_advanced_debug_log_section_header"))
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
                                Button(BundleUtil.localizedString(forKey: "copy"), action: {
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
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_reregister_notifications_label"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Text(BundleUtil.localizedString(forKey: "settings_advanced_reregister_push_notifications_header_title"))
            } footer: {
                Text(BundleUtil.localizedString(forKey: "settings_advanced_reregister_push_notifications_footer_title"))
            }
            
            // MARK: Other settings
            
            Section {
                NavigationLink {
                    CallDiagnosticViewControllerRepresentable()
                        .ignoresSafeArea(.all)
                        .navigationBarTitle("webrtc_diagnostics.title", displayMode: .inline)
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_webrtc_diagnostics_title"))
                }
                
                NavigationLink {
                    OrphanedFilesCleanupViewControllerRepresentable()
                        .ignoresSafeArea(.all)
                        .navigationBarTitle("settings_advanced_orphaned_files_cleanup", displayMode: .inline)
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_orphaned_files_cleanup"))
                }

                NavigationLink {
                    ContactsCleanupView(settingsStore: settingsVM)
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup"))
                }

                Button {
                    flushMessageQueue()
                } label: {
                    HStack {
                        Spacer()
                        Text(BundleUtil.localizedString(forKey: "settings_advanced_flush_message_queue"))
                        Spacer()
                    }
                }
            } header: {
                Text(BundleUtil.localizedString(forKey: "settings_advanced_other_section_header"))
            }
            
            // MARK: Safe mode Settings
            
            if SettingsBundleHelper.safeMode {
                Section {
                    Button {
                        let businessInjector = BusinessInjector()
                        businessInjector.backgroundEntityManager.performAndWaitSave {
                            let unreadMessages = UnreadMessages(entityManager: businessInjector.backgroundEntityManager)
                            
                            let batch = NSBatchUpdateRequest(entityName: "Message")
                            batch.resultType = .statusOnlyResultType
                            batch.predicate = NSPredicate(format: "read == false && isOwn == false")
                            batch.propertiesToUpdate = ["read": true]
                            if let batchResult = businessInjector.backgroundEntityManager.entityFetcher.execute(batch) {
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
                                array: businessInjector.backgroundEntityManager
                                    .entityFetcher.allConversations()
                            ) as? Set<Conversation> {
                                unreadMessages.totalCount(
                                    doCalcUnreadMessagesCountOf: allConversations,
                                    withPerformBlockAndWait: true
                                )
                            }
                        }
                        
                        NotificationManager().updateUnreadMessagesCount()
                        NotificationBannerHelper.newSuccessToast(
                            title: "settings_advanced_successfully_reset_unread_count_label".localized,
                            body: "ok".localized
                        )

                        let delay = DispatchTime.now() + DispatchTimeInterval.seconds(3)
                        DispatchQueue.main.asyncAfter(deadline: delay) {
                            SettingsBundleHelper.resetSafeMode()
                            exit(0)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(BundleUtil.localizedString(forKey: "settings_advanced_reset_unread_count_label"))
                            Spacer()
                        }
                    }
                    
                    Button {
                        SQLDHSessionStore.deleteSessionDB()
                    } label: {
                        HStack {
                            Spacer()
                            Text(BundleUtil.localizedString(forKey: "settings_advanced_reset_fs_db_label"))
                            Spacer()
                        }
                    }
                } header: {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_support_settings_header"))
                } footer: {
                    Text(BundleUtil.localizedString(forKey: "settings_advanced_support_settings_footer_title"))
                }
            }
        }
        .navigationBarTitle(BundleUtil.localizedString(forKey: "settings_advanced"), displayMode: .inline)
        .tint(UIColor.primary.color)
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
                    currentWindow.view.bounds.center.y,
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
        let entityManager = BusinessInjector().entityManager
        DDLogNotice(
            "There are \(entityManager.entityFetcher.countFileMessagesWithNoMIMEType()) file messages with no MIME type"
        )
    }
}

struct AdvancedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdvancedSettingsView(settingsVM: SettingsStore())
        }
    }
}
