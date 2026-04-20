import CocoaLumberjackSwift
import FileUtility
import Intents
import Keychain
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

struct DeveloperSettingsView: View {
        
    // Multi-Device
    @State var allowSeveralDevices = UserSettings.shared().allowSeveralLinkedDevices
    @State private var showDebugDeviceJoin = false
    
    // Feature Flags
    @State var ipcCommunicationEnabled = UserSettings.shared().ipcCommunicationEnabled
    @State var distributionListsEnabled = UserSettings.shared().distributionListsEnabled
    
    // Group Calls
    @State var groupCallsDebugMessages = UserSettings.shared().groupCallsDebugMessages
    
    // Confirm deletion
    @State private var showDeleteKeychainItemsConfirmation = false
    @State private var showDeleteAllDataConfirmation = false
    @State private var showDeleteAllKeychainItemsConfirmation = false

    var body: some View {
        List {
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
                #if DEBUG
                    Toggle(isOn: $distributionListsEnabled) {
                        Text(verbatim: "Enable Distribution Lists Feature")
                    }
                    .onChange(of: distributionListsEnabled) {
                        UserSettings.shared().distributionListsEnabled = distributionListsEnabled
                    }
                #endif
            }
            header: {
                Text(verbatim: "Feature Flags")
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
            if ThreemaEnvironment.env() == .xcode || ThreemaEnvironment.env() == .testFlight {
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
                            if ThreemaEnvironment.env() == .xcode {
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
                            // DB & Files
                            FileUtility.shared.removeItemsInAllDirectories(appGroupID: AppGroup.groupID())
                            AppGroup.resetUserDefaults()
                            try? PersistenceManager(
                                appGroupID: AppGroup.groupID(),
                                userDefaults: AppGroup.userDefaults(),
                                remoteSecretManager: AppLaunchManager.remoteSecretManager
                            ).databaseManager.eraseDB()
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
                    exit(1)
                } label: {
                    Text(verbatim: "Crash the app")
                }
            } header: {
                Text(verbatim: "Crash")
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
                        audioSessionManager: AudioSessionManager(),
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
            DeveloperSettingsView()
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
