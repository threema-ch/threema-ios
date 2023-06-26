//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import SwiftUI

// This is a WIP thus some things are not completed:
// TODO: Add localized strings
// TODO: Add hidden feature to link multiple devices for testing
// TODO: Check if function from old settings are still missing

/// Enable Multi-Device with initial device or show existing linked devices
struct LinkedDevicesView: View {
    
//    @EnvironmentObject var settingsStore: SettingsStore
    @ObservedObject var settingsStore: SettingsStore

    @State private var showWizard = false
    
    var body: some View {
        // Group so that we can add navigation title and sheet
        Group {
            if settingsStore.isMultiDeviceEnabled {
                EnabledMultiDeviceView(showWizard: $showWizard)
            }
            else {
                DisabledMultiDeviceView(showWizard: $showWizard)
            }
        }
        .navigationBarTitle(Text("WIP: Linked Device (beta)"), displayMode: .inline)
        .sheet(isPresented: $showWizard) {
            Text("TODO: Implement new 📱🔗🧙🏼‍♂️...")
        }
    }
}

struct LinkedDevices_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LinkedDevicesView(settingsStore: SettingsStore())
        }
    }
}

// MARK: - Private Views

// MARK: EnabledMultiDeviceView

struct EnabledMultiDeviceView: View {

    @Binding var showWizard: Bool
    
    private let businessInjector = BusinessInjector()
    
    @State private var thisDevice: DeviceInfo?
    @State private var otherDevices = [DeviceInfo]()
    
    var body: some View {
        List {
            // TODO: Wait until devices are loaded or show error (also if offline)
            Section {
                ForEach(otherDevices) { device in
                    LinkedDeviceListView(device: device)
                }
                .onDelete { indexSet in
                    // TODO: Implement proper delete action
                    print("Delete: \(indexSet)")
                }
                
                Button {
                    // TODO: Check if same ID exists multiple times
                    showWizard.toggle()
                } label: {
                    HStack {
                        SettingsListView(cellTitle: "Add Device", imageSystemName: "desktopcomputer")
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle()) // Needed to make all of the cell tappable
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
            
            if let thisDevice {
                Section("This Device") {
                    LinkedDeviceListView(device: thisDevice)
                }
            }
            
            Section {
                Button {
                    // TODO: Disable MD
                    print("TODO: Remove all linked devices")
                } label: {
                    Text("Remove All Linked Devices")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .task {
            refresh()
        }
        .refreshable {
            refresh()
        }
    }
    
    private func refresh() {
        thisDevice = businessInjector.multiDeviceManager.thisDevice
        
        businessInjector.multiDeviceManager.otherDevices()
            .done { devicesInfo in
                otherDevices = devicesInfo
            }
            .catch { error in
                DDLogError("Error: \(error)")
                
                // TODO: Show alert
            }
    }
}

struct EnabledMultiDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EnabledMultiDeviceView(showWizard: .constant(false))
                .environmentObject(SettingsStore())
        }
    }
}

// MARK: DisabledMultiDeviceView

struct DisabledMultiDeviceView: View {
    @Binding var showWizard: Bool
    
    var body: some View {
        List {
            Section {
                Button {
                    // TODO: Check if same ID exists multiple times
                    showWizard.toggle()
                } label: {
                    HStack {
                        SettingsListView(cellTitle: "Add Device", imageSystemName: "desktopcomputer")
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle()) // Needed to make all of the cell tappable
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Download Threema Work (beta) on your computer and start it: TODO")
            }
        }
    }
}

struct DisabledMultiDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DisabledMultiDeviceView(showWizard: .constant(false))
                .environmentObject(SettingsStore())
        }
    }
}

// MARK: LinkedDeviceListView

struct LinkedDeviceListView: View {
    
    @Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
    
    let device: DeviceInfo
    
    var body: some View {
        HStack(spacing: 12) {
            if !sizeCategory.isAccessibilityCategory {
                Image(systemName: device.platform.systemSymbolName)
                    .foregroundColor(UIColor.primary.color)
                    .imageScale(.large)
                    .font(.title)
                    .frame(width: 50, alignment: .center)
            }

            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text(device.label)
                        .font(.headline)
                    
                    if let badge = device.badge {
                        Text(badge)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                Group {
                    Text(device.platformDetails ?? "No platform details")

                    Text(
                        "Last active: \(DateFormatter.relativeLongStyleDateShortStyleTime(device.lastLoginAt))"
                    )
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
    }
}

struct LinkedDeviceListView_Previews: PreviewProvider {
    
    private static let deviceInfos = [
        DeviceInfo(
            deviceID: 1,
            label: "iPhone 5.0 (5000-T)",
            lastLoginAt: .now,
            badge: nil,
            platform: .ios,
            platformDetails: "iPhone 14 Pro"
        ),
        DeviceInfo(
            deviceID: 2,
            label: "Desktop 2.0 (Preview 10)",
            lastLoginAt: .now,
            badge: nil,
            platform: .desktop,
            platformDetails: "Elektron 23"
        ),
        DeviceInfo(
            deviceID: 3,
            label: "Firefox 112.0.2",
            lastLoginAt: .now,
            badge: "Volatile Session",
            platform: .web,
            platformDetails: "Firefox 112.0.2"
        ),
    ]
    
    static var previews: some View {
        List(deviceInfos, id: \.deviceID) { device in
            LinkedDeviceListView(device: device)
        }
        .previewLayout(.sizeThatFits)
    }
}
