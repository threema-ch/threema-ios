import CocoaLumberjackSwift
import DataBackup
import FileUtility
import Intents
import Keychain
import Sentry
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

struct DeveloperSettingsView: View {

    /// Launches the child-coordinator chain demo. Routed through
    /// `SettingsCoordinator` so the demo pushes onto the settings tab's shared
    /// navigation path (see `SettingsCoordinatorDemo`).
    let onStartCoordinatorDemo: () -> Void

    let appFlavorService: any AppFlavorServiceProtocol = AppFlavorService()

    // Local Backups
    @State var localBackupDebugRecoveryKeyEnabled = UserSettings.shared().localBackupDebugRecoveryKeyEnabled

    // Multi-Device
    @State var allowSeveralDevices = UserSettings.shared().allowSeveralLinkedDevices
    @State private var showDebugDeviceJoin = false
    
    // Feature Flags
    @State var ipcCommunicationEnabled = UserSettings.shared().ipcCommunicationEnabled
    @State var distributionListsEnabled = UserSettings.shared().distributionListsEnabled
    @State var backups2Enabled = UserSettings.shared().backups2Enabled
    
    // Group Calls
    @State var groupCallsDebugMessages = UserSettings.shared().groupCallsDebugMessages
    
    // Confirm deletion
    @State private var showDeleteKeychainItemsConfirmation = false
    @State private var showDeleteAllDataConfirmation = false
    @State private var showDeleteAllKeychainItemsConfirmation = false

    var body: some View {
        List {
            Section {
                #if DEBUG
                    Toggle(isOn: $distributionListsEnabled) {
                        Text(verbatim: "Enable Distribution Lists Feature")
                    }
                    .onChange(of: distributionListsEnabled) {
                        UserSettings.shared().distributionListsEnabled = distributionListsEnabled
                    }

                    Toggle(isOn: $backups2Enabled) {
                        Text(verbatim: "Enable Cross Platform Backup Feature")
                    }
                    .onChange(of: backups2Enabled) {
                        UserSettings.shared().backups2Enabled = backups2Enabled
                    }
                #endif
            }
            header: {
                Text(verbatim: "Feature Flags")
            }

            if appFlavorService.isSandbox || EnvironmentType.current == .testFlight {
                Section {
                    Toggle(isOn: $localBackupDebugRecoveryKeyEnabled) {
                        Text(verbatim: "Generate same backup password")
                    }
                    .onChange(of: localBackupDebugRecoveryKeyEnabled) {
                        UserSettings.shared().localBackupDebugRecoveryKeyEnabled = localBackupDebugRecoveryKeyEnabled
                    }
                }
                header: {
                    Text(verbatim: "Local Backups")
                }
                footer: {
                    Text(
                        verbatim: "Uses \(DebugBackupEncryptionKeyService.key.prefix(8))… (\(DebugBackupEncryptionKeyService.key.count) times 1) as the recovery key instead of random one. Takes effect after the next app start."
                    )
                }
            }

            Section {
                HStack {
                    Text(verbatim: "Last sent FeatureMask")
                    Spacer()
                    Text(verbatim: "\(MyIdentityStore.shared().lastSentFeatureMask)")
                        .foregroundStyle(.secondary)
                }
            }
            header: {
                Text(verbatim: "Local Info")
            }
            footer: {
                Text(verbatim: "Does not refresh automatically.")
            }

            Section {
                Button {
                    onStartCoordinatorDemo()
                } label: {
                    HStack {
                        Text(verbatim: "Coordinator Demo")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
            }
            header: {
                Text(verbatim: "Coordinator")
            }

            Section {
                NavigationLink {
                    UIComponentsView()
                } label: {
                    Text(verbatim: "UI Components Debug View")
                }
                
                NavigationLink {
                    StyleKitView()
                } label: {
                    Text(verbatim: "StyleKit Debug View")
                }
                
                NavigationLink {
                    ProfilePictureDebugView()
                } label: {
                    Text(verbatim: "Profile Picture Debug View")
                }
                
                NavigationLink {
                    IDColorsView()
                } label: {
                    Text(verbatim: "ID Colors Debug View")
                }
                
                NavigationLink {
                    ThreemaButtonView()
                } label: {
                    Text(verbatim: "Buttons")
                }
                
                NavigationLink {
                    LaunchModalSettingsView()
                } label: {
                    Text(verbatim: "Launch Modals")
                }

                NavigationLink {
                    NotificationsAndAlertsView()
                } label: {
                    Text(verbatim: "Notifications / Alerts")
                }

                Button {
                    UserSettings.shared().resetTipKitOnNextLaunch = true
                    exit(1)
                } label: {
                    Text(verbatim: "Reset TipKit (Relaunches App)")
                }
            }
            header: {
                Text(verbatim: "UI")
            }
            
            Section {
                HStack {
                    Text(verbatim: "Is Leader (Reopen view to update)")
                    Spacer()
                    Text(verbatim: "\((ServerConnector.shared().isRolePromotedToLeader) ? "Yes" : "No")")
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    showDebugDeviceJoin = true
                } label: {
                    Text(verbatim: "Show Device Join Debug View")
                }
                
                Toggle(isOn: $allowSeveralDevices) {
                    VStack(alignment: .leading) {
                        Text(verbatim: "Allow Multiple Linked Devices")
                        Text(
                            verbatim: "Enable this if you want to link other iOS devices. Multiple Desktop clients are always enabled."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: allowSeveralDevices) {
                    UserSettings.shared().allowSeveralLinkedDevices = allowSeveralDevices
                }
                
                NavigationLink {
                    MultiDeviceViewControllerRepresentable()
                } label: {
                    VStack(alignment: .leading) {
                        Text(verbatim: "Old Linking ⚠️")
                        Text(
                            verbatim: "Use to link another iOS device. Enable setting above and tap on iPhone Symbol to start linking another device.\nUse on your own risk!"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            header: {
                Text(verbatim: "Multi-Device")
            }
            
            Section {
                Toggle(isOn: $groupCallsDebugMessages) {
                    Text(verbatim: "Send Debug Messages for Group Calls")
                }
                .onChange(of: groupCallsDebugMessages) {
                    UserSettings.shared().groupCallsDebugMessages = groupCallsDebugMessages
                }
            }
            header: {
                Text(verbatim: "Group Calls")
            }

            Section {
                Button {
                    let businessInjector = BusinessInjector.ui
                    let terminator = try! ForwardSecuritySessionTerminator(businessInjector: businessInjector)
                    
                    businessInjector.entityManager.performAndWaitSave {
                        for contact in businessInjector.entityManager.entityFetcher
                            .contactEntities() ?? [] {
                            _ = try! terminator.terminateAllSessions(with: contact, cause: .reset)
                        }
                    }
                } label: {
                    Text(verbatim: "Terminate All FS Sessions")
                }
                
                Button {
                    let businessInjector = BusinessInjector.ui
                    let terminator = try! ForwardSecuritySessionTerminator(businessInjector: businessInjector)
                    
                    businessInjector.entityManager.performAndWait {
                        for contact in businessInjector.entityManager.entityFetcher
                            .contactEntities() ?? [] {
                            try! terminator.deleteAllSessions(with: contact)
                        }
                    }
                } label: {
                    Text(verbatim: "🚨 Delete All FS Sessions")
                }
            }
            header: {
                Text(verbatim: "🚨🚨 FS State Deletion")
            }
            footer: {
                Text(verbatim: "This will delete data without any additional confirmation!")
                    .bold()
                    .foregroundColor(.red)
            }
            
            // Add this option to testflight for green and blue apps
            if EnvironmentType.current == .xcode || EnvironmentType.current == .testFlight {
                Section {
                    Button {
                        showDeleteKeychainItemsConfirmation = true
                    } label: {
                        Text(verbatim: "🚨 Simulate Restore (Delete relevant Keychain items)")
                    }
                    .confirmationDialog(
                        Text(verbatim: "To restore your ID, you will need an ID Backup or a Threema Safe Backup."),
                        isPresented: $showDeleteKeychainItemsConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button {
                            if EnvironmentType.current == .xcode {
                                try? KeychainManager.deleteAllThisDeviceOnlyItems()
                                
                                exit(1)
                            }
                            else {
                                DDLogWarn("Delete Keychain Items is for testing only")
                            }
                        } label: {
                            Text(verbatim: "Delete Keychain Items")
                        }
                    }
                    message: {
                        Text(
                            verbatim:
                            "Client key, device group key and further items will be deleted. This simulates restoring a Finder/iTunes/iCloud backup to a new device (or Quick Start)."
                        )
                    }
                    
                    Button {
                        showDeleteAllDataConfirmation = true
                    } label: {
                        Text(verbatim: "🚨 Delete Database, Settings & All Files")
                    }
                    .confirmationDialog(
                        Text(verbatim: "Delete Database, Settings & All Files"),
                        isPresented: $showDeleteAllDataConfirmation
                    ) {
                        Button {
                            // Destroy CoreData SQLite and associated files (-wal, -shm)
                            try? PersistenceManager(
                                appGroupID: AppGroup.groupID(),
                                userDefaults: AppGroup.userDefaults(),
                                remoteSecretManager: RemoteSecretProvider.remoteSecretManager
                            ).databaseManager.eraseDB()

                            // Close the Threema-FS session store before unlinking its file
                            BusinessInjector.ui.dhSessionStore.close()

                            // Remaining Files
                            FileUtility.shared.removeItemsInAllDirectories(appGroupID: AppGroup.groupID())

                            // User Defaults
                            UserDefaults.resetStandardUserDefaults()
                            AppGroup.resetUserDefaults()

                            // Safe to exit.
                            exit(0)
                        } label: {
                            Text(verbatim: "Delete Everything")
                        }
                    }
                } header: {
                    Text(verbatim: "🚨🚨🚨 Data Deletion")
                }
            }
            
            Section {
                Button {
                    Sentry.SentrySDK.capture(message: "Test event from developer settings")
                } label: {
                    Text(verbatim: "Capture test Sentry event")
                }

                Button {
                    Sentry.SentrySDK.crash()
                } label: {
                    Text(verbatim: "Crash the app")
                }
            } header: {
                Text(verbatim: "Sentry")
            } footer: {
                Text(
                    verbatim: "\"Capture test Sentry event\" runs the consent flow in-session. \"Crash the app\" only produces a report when run without the Xcode debugger attached: crash, then relaunch from the home screen."
                )
            }

            #if DEBUG
                Section {
                    Button {
                        KeychainManager.printKeychainItems()
                    } label: {
                        Text(verbatim: "Print all Keychain items")
                    }
                    Button {
                        showDeleteAllKeychainItemsConfirmation = true
                    } label: {
                        Text(verbatim: "🚨🚨🚨 Delete all Keychain items")
                    }
                    .confirmationDialog(
                        Text(
                            verbatim: "Are you sure you want to delete all Keychain items of the type kSecClass: kSecClassGenericPassword?"
                        ),
                        isPresented: $showDeleteAllKeychainItemsConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button {
                            KeychainManager.deleteKeychainItemsExceptIdentity()

                            exit(0)
                        } label: {
                            Text(verbatim: "Delete all Keychain items")
                        }
                    }
                } header: {
                    Text(verbatim: "Keychain")
                }

            #endif
        }
        .navigationBarTitle(Text(verbatim: "Developer Settings"), displayMode: .inline)
        .tint(.accentColor)
        .sheet(isPresented: $showDebugDeviceJoin) {
            NavigationStack {
                DebugDeviceJoinView(
                    model: QRCodeScannerViewModel(
                        mode: .multiDeviceLink,
                        audioSessionManager: BusinessInjector.ui.audioSessionManager,
                        systemFeedbackManager: SystemFeedbackManager(
                            deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                            settingsStore: BusinessInjector.ui.settingsStore
                        ),
                        systemPermissionsManager: SystemPermissionsManager()
                    )
                )
            }
        }
    }
}

struct DevModeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeveloperSettingsView(onStartCoordinatorDemo: { })
        }
    }
}

// MARK: - ViewController Representables

private struct UIComponentsView: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        UIComponentsViewController()
    }
}

private struct StyleKitView: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        StyleKitDebugViewController()
    }
}

private struct IDColorsView: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        IDColorDebugViewController()
    }
}
