//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

struct DeveloperSettingsView: View {
        
    // Multi-Device
    @State var allowSeveralDevices = UserSettings.shared().allowSeveralLinkedDevices
    @State private var showDebugDeviceJoin = false
    
    // Feature Flags
    @State var contactList2 = UserSettings.shared().contactList2
    
    // Group Calls
    @State var groupCallsDebugMessages = UserSettings.shared().groupCallsDebugMessages
    
    // Confirm deletion
    @State private var showDeleteKeychainItemsConfirmation = false
    @State private var showDeleteAllDataConfirmation = false

    var body: some View {
        List {
            Section("Local Info") {
                HStack {
                    Text("Last sent FeatureMask")
                    Spacer()
                    Text("\(MyIdentityStore.shared().lastSentFeatureMask)")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("UI") {
                NavigationLink {
                    UIComponentsView()
                } label: {
                    Text("UI Components Debug View")
                }
                
                NavigationLink {
                    StyleKitView()
                } label: {
                    Text("StyleKit Debug View")
                }
                
                NavigationLink {
                    IDColorsView()
                } label: {
                    Text("ID Colors Debug View")
                }
                
                NavigationLink {
                    LaunchModalSettingsView()
                } label: {
                    Text("Launch Modals")
                }
            }
            
            Section("Multi-Device") {
                Toggle(isOn: $allowSeveralDevices) {
                    Text("Allow several linked devices")
                }
                .onChange(of: allowSeveralDevices) { newValue in
                    UserSettings.shared().allowSeveralLinkedDevices = newValue
                }
                
                Button("Show Debug Device Join") {
                    showDebugDeviceJoin = true
                }
                
                NavigationLink {
                    LinkedDevicesView()
                } label: {
                    Text("Linked Device (beta)")
                }
                
                NavigationLink {
                    MultiDeviceViewControllerRepresentable()
                } label: {
                    Text("Old Linking")
                }
            }
            
            Section("Feature Flags") {
                Toggle(isOn: $contactList2) {
                    Text("Enable Contact List 2.0")
                }
                .onChange(of: contactList2) { newValue in
                    UserSettings.shared().contactList2 = newValue
                    exit(1)
                }
            }
            
            Section("Group Calls") {
                Toggle(isOn: $groupCallsDebugMessages) {
                    Text("Send Debug Messages for Group Calls")
                }
                .onChange(of: groupCallsDebugMessages) { newValue in
                    UserSettings.shared().groupCallsDebugMessages = newValue
                }
            }
            
            Section {
                Button("Terminate All FS Sessions") {
                    let businessInjector = BusinessInjector()
                    let terminator = try! ForwardSecuritySessionTerminator(businessInjector: businessInjector)
                    
                    businessInjector.entityManager.performAndWait {
                        for contact in businessInjector.entityManager.entityFetcher
                            .allContacts() as? [ContactEntity] ?? [] {
                            try! terminator.terminateAllSessions(with: contact, cause: .reset)
                        }
                    }
                }
                
                Button("🚨 Delete All FS Sessions") {
                    let businessInjector = BusinessInjector()
                    let terminator = try! ForwardSecuritySessionTerminator(businessInjector: businessInjector)
                    
                    businessInjector.entityManager.performAndWait {
                        for contact in businessInjector.entityManager.entityFetcher
                            .allContacts() as? [ContactEntity] ?? [] {
                            try! terminator.deleteAllSessions(with: contact)
                        }
                    }
                }
            }
            header: {
                Text("🚨🚨 FS State Deletion")
            }
            footer: {
                Text("This will delete data without any additional confirmation!")
                    .bold()
                    .foregroundColor(.red)
            }
            
            if ThreemaEnvironment.env() == .xcode {
                Section("🚨🚨🚨 Data Deletion") {
                    Button("🚨 Simulate Restore (Delete Keychain)") {
                        showDeleteKeychainItemsConfirmation = true
                    }
                    .confirmationDialog(
                        "To restore your ID, you will need an ID Backup or a Threema Safe Backup.",
                        isPresented: $showDeleteKeychainItemsConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Keychain Items", role: .destructive) {
                            MyIdentityStore.shared().destroyDeviceOnlyKeychainItems()

                            if let identity = MyIdentityStore.shared().identity {
                                let keychainHelper = KeychainHelper(identity: ThreemaIdentity(identity))
                                try? keychainHelper.destroy(item: .threemaSafeKey)
                                try? keychainHelper.destroy(item: .threemaSafeServer)
                            }

                            exit(0)
                        }
                    }
                    message: {
                        Text(
                            "ID private key, device group key and further items will be deleted. This simulates restoring a Finder/iTunes/iCloud backup to a new device (or Quick Start)."
                        )
                    }
                    
                    Button("🚨 Delete Database, Settings & All Files") {
                        showDeleteAllDataConfirmation = true
                    }
                    .confirmationDialog(
                        "Delete Database, Settings & All Files",
                        isPresented: $showDeleteAllDataConfirmation
                    ) {
                        Button("Delete Everything", role: .destructive) {
                            // DB & Files
                            FileUtility.shared.removeItemsInAllDirectories()
                            AppGroup.resetUserDefaults()
                            DatabaseManager().eraseDB()
                            exit(0)
                        }
                    }
                }
            }
            
            Section("Crash") {
                Button("Crash the app") {
                    var nilString: String?
                    print(nilString!)
                }
            }
        }
        .navigationBarTitle("Developer Settings", displayMode: .inline)
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
