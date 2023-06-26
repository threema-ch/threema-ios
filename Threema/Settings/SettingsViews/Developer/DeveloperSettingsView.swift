//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import ThreemaFramework

struct DeveloperSettingsView: View {
        
    // New ChatView
    @State var flippedTableView = UserSettings.shared().flippedTableView

    // Multi-Device
    @State var allowSeveralDevices = UserSettings.shared().allowSeveralLinkedDevices
    
    // Feature Flags
    @State var newSettings = UserSettings.shared().newSettingsActive
    
    var body: some View {
        List {
            Section("New ChatView") {
                Toggle(isOn: $flippedTableView) {
                    Text("Flip TableView")
                }
                .onChange(of: flippedTableView) { newValue in
                    UserSettings.shared().flippedTableView = newValue
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
                
                NavigationLink {
                    LinkedDevicesView(settingsStore: BusinessInjector().settingsStore as! SettingsStore)
                } label: {
                    Text("Linked Device (beta)")
                }
            }
            
            Section("Feature Flags") {
                Toggle(isOn: $newSettings) {
                    Text("SwiftUI Settings")
                }
                .onChange(of: newSettings) { newValue in
                    UserSettings.shared().newSettingsActive = newValue
                    exit(1)
                }
                Text("GroupCalls soon? ☎️👀")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .navigationBarTitle("Developer Settings", displayMode: .inline)
        .tint(UIColor.primary.color)
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
