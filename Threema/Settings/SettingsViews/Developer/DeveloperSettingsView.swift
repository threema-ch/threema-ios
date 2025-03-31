//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import Intents
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

struct DeveloperSettingsView: View {
        
    // Multi-Device
    @State var allowSeveralDevices = UserSettings.shared().allowSeveralLinkedDevices
    @State private var showDebugDeviceJoin = false
    
    // Feature Flags
    @State var contactList2 = UserSettings.shared().contactList2
    
    @State var ipcCommunicationEnabled = UserSettings.shared().ipcCommunicationEnabled

    // Group Calls
    @State var groupCallsDebugMessages = UserSettings.shared().groupCallsDebugMessages
    
    // Confirm deletion
    @State private var showDeleteKeychainItemsConfirmation = false
    @State private var showDeleteAllDataConfirmation = false

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
                    LaunchModalSettingsView()
                } label: {
                    Text(verbatim: "Launch Modals")
                }
                
                NavigationLink {
                    AudioErrorDebugView()
                } label: {
                    Text(verbatim: "Audio Error Debug View")
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
                .onChange(of: allowSeveralDevices) { newValue in
                    UserSettings.shared().allowSeveralLinkedDevices = newValue
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
                Toggle(isOn: $contactList2) {
                    Text(verbatim: "Enable Contact List 2.0")
                }
                .onChange(of: contactList2) { newValue in
                    UserSettings.shared().contactList2 = newValue
                    exit(1)
                }
                
                Toggle(isOn: $ipcCommunicationEnabled) {
                    Text(verbatim: "IPC Communication")
                }
                .onChange(of: ipcCommunicationEnabled) { newValue in
                    UserSettings.shared().ipcCommunicationEnabled = newValue
                }
            }
            header: {
                Text(verbatim: "Feature Flags")
            }
            
            Section {
                Toggle(isOn: $groupCallsDebugMessages) {
                    Text(verbatim: "Send Debug Messages for Group Calls")
                }
                .onChange(of: groupCallsDebugMessages) { newValue in
                    UserSettings.shared().groupCallsDebugMessages = newValue
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
                            .allContacts() as? [ContactEntity] ?? [] {
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
                            .allContacts() as? [ContactEntity] ?? [] {
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
                        Text(verbatim: "🚨 Simulate Restore (Delete Keychain)")
                    }
                    .confirmationDialog(
                        Text(verbatim: "To restore your ID, you will need an ID Backup or a Threema Safe Backup."),
                        isPresented: $showDeleteKeychainItemsConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button {
                            MyIdentityStore.shared().destroyDeviceOnlyKeychainItems()

                            if let identity = MyIdentityStore.shared().identity {
                                let keychainHelper = KeychainHelper(identity: ThreemaIdentity(identity))
                                try? keychainHelper.destroy(item: .threemaSafeKey)
                                try? keychainHelper.destroy(item: .threemaSafeServer)
                            }

                            exit(0)
                        } label: {
                            Text(verbatim: "Delete Keychain Items")
                        }
                    }
                    message: {
                        Text(
                            verbatim:
                            "ID private key, device group key and further items will be deleted. This simulates restoring a Finder/iTunes/iCloud backup to a new device (or Quick Start)."
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
                            FileUtility.shared.removeItemsInAllDirectories()
                            AppGroup.resetUserDefaults()
                            DatabaseManager().eraseDB()
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
                    var nilString: String?
                    print(nilString!)
                } label: {
                    Text(verbatim: "Crash the app")
                }
            } header: {
                Text(verbatim: "Crash")
            }
        }
        .navigationBarTitle(Text(verbatim: "Developer Settings"), displayMode: .inline)
        .tint(UIColor.primary.color)
        .sheet(isPresented: $showDebugDeviceJoin) {
            DebugDeviceJoinView()
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
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "ComponentsVC")
        return vc
    }
}

private struct StyleKitView: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "StyleKitVC")
        return vc
    }
}

private struct IDColorsView: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "IDColorsVC")
        return vc
    }
}
