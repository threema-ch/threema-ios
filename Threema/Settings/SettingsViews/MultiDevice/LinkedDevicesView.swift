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
// TODO: (IOS-3896) Add localized strings
// TODO: (IOS-3897) Add hidden feature to link multiple devices for testing

/// Enable Multi-Device with initial device or show existing linked devices
struct LinkedDevicesView: View {
    
//    @EnvironmentObject var settingsStore: SettingsStore
    @ObservedObject var settingsStore: SettingsStore

    @State private var showWizard = false
    
    var body: some View {
        // Stack so that we can add navigation title and sheet
        VStack {
            if settingsStore.isMultiDeviceRegistered {
                EnabledMultiDeviceListView(showWizard: $showWizard)
            }
            else {
                DisabledMultiDeviceListView(showWizard: $showWizard)
            }
        }
        .navigationBarTitle(
            Text(BundleUtil.localizedString(forKey: "multi_device_new_linked_devices_title")),
            displayMode: .inline
        )
        .sheet(isPresented: $showWizard) {
            DeviceJoinView(settingsStore: settingsStore, showWizard: $showWizard)
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

// MARK: EnabledMultiDeviceListView

struct EnabledMultiDeviceListView: View {
    
    private enum LinkedDevicesState: Equatable {
        case refreshing
        case error
        case linkedDevices(devicesInfo: [DeviceInfo])
    }

    @Binding var showWizard: Bool // Needed if adding multiple devices is enabled
    
    private let businessInjector = BusinessInjector()
    
    @State private var linkedDevicesState: LinkedDevicesState = .refreshing
        
    @State private var showDisableMultiDeviceConfirmation = false
    @State private var showRemovingError = false
    
    var body: some View {
        List {
            // As a somewhat hacky solution we use section footers for a nicer appearance of the texts & progress
            switch linkedDevicesState {
            case .refreshing:
                Section {
                    // No row
                } footer: {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                }
            case .error:
                Section {
                    // No row
                } footer: {
                    Text(
                        BundleUtil.localizedString(
                            forKey: "multi_device_new_linked_devices_failed_to_load"
                        )
                    )
                }
            case let .linkedDevices(devicesInfo: devicesInfo):
                if !devicesInfo.isEmpty {
                    Section {
                        ForEach(devicesInfo) { device in
                            LinkedDeviceListView(device: device)
                        }
                    } footer: {
                        Text(BundleUtil.localizedString(forKey: "multi_device_new_linked_devices_limitation_info"))
                    }
                }
                else {
                    Section {
                        // No row
                    } footer: {
                        // TODO: (IOS-3939) How do we handle if probably no device is linked, but md enabled?
                        Text(String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "multi_device_new_linked_devices_no_other_device"),
                            BundleUtil.localizedString(forKey: "multi_device_new_linked_device_remove_all_button")
                        ))
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showDisableMultiDeviceConfirmation = true
                } label: {
                    Text(BundleUtil.localizedString(forKey: "multi_device_new_linked_device_remove_all_button"))
                        .frame(maxWidth: .infinity)
                }
                .disabled(linkedDevicesState == .refreshing)
                .confirmationDialog(
                    BundleUtil.localizedString(forKey: "multi_device_new_linked_device_remove_all_title"),
                    isPresented: $showDisableMultiDeviceConfirmation
                ) {
                    Button(
                        BundleUtil.localizedString(forKey: "multi_device_new_linked_device_remove_all_button"),
                        role: .destructive
                    ) {
                        linkedDevicesState = .refreshing
                        Task(priority: .userInitiated) {
                            do {
                                try await businessInjector.multiDeviceManager.disableMultiDevice()
                            }
                            catch {
                                DDLogError("Error disabling multi device: \(error)")
                                
                                showRemovingError = true
                            }
                        }
                    }
                }
            }
        }
        .task {
            linkedDevicesState = .refreshing
            refresh()
        }
        .refreshable {
            refresh()
        }
        .onChange(of: showWizard) { newValue in
            if newValue == false {
                linkedDevicesState = .refreshing
                refresh()
            }
        }
        .alert(
            BundleUtil.localizedString(forKey: "multi_device_new_linked_device_remove_all_error_title"),
            isPresented: $showRemovingError
        ) {
            Button("OK") {
                linkedDevicesState = .refreshing
                refresh()
            }
        } message: {
            Text(BundleUtil.localizedString(forKey: "multi_device_new_linked_device_error_message"))
        }
    }
    
    private func refresh() {
        businessInjector.multiDeviceManager.otherDevices()
            .done { devicesInfo in
                linkedDevicesState = .linkedDevices(devicesInfo: devicesInfo)
            }
            .catch { error in
                DDLogError("Failed to load device list: \(error)")
                
                linkedDevicesState = .error
            }
    }
}

struct EnabledMultiDeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EnabledMultiDeviceListView(showWizard: .constant(false))
                .environmentObject(SettingsStore())
        }
    }
}

// MARK: DisabledMultiDeviceListView

struct DisabledMultiDeviceListView: View {
    
    @Binding var showWizard: Bool
    
    private let businessInjector = BusinessInjector()
    
    @State private var duplicateContactIdentities: [String] = []
    
    @State private var showOwnIdentityInContactsAlert = false
    @State private var showPasscodeView = false
    
    var body: some View {
        List {
            Section {
                Button {
                    if businessInjector.entityManager.entityFetcher.contactsContainOwnIdentity() {
                        showOwnIdentityInContactsAlert = true
                    }
                    else if KKPasscodeLock.shared().isPasscodeRequired() {
                        showPasscodeView = true
                    }
                    else {
                        showWizard = true
                    }
                } label: {
                    HStack {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "multi_device_new_linked_devices_add_button"),
                            imageSystemName: "desktopcomputer"
                        )
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle()) // Needed to make all of the cell tappable
                }
                .buttonStyle(.plain)
                .disabled(!duplicateContactIdentities.isEmpty)
            } footer: {
                if duplicateContactIdentities.isEmpty {
                    Text("""
                        \(String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "multi_device_new_linked_device_instructions"),
                        ThreemaApp.appName,
                        DeviceJoinManager.downloadURL
                        ))
                        
                        \(BundleUtil.localizedString(forKey: "multi_device_new_linked_devices_limitation_info"))
                        """)
                }
                else {
                    Text(String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "multi_device_linked_duplicate_contacts_desc"),
                        ListFormatter.localizedString(byJoining: Array(duplicateContactIdentities))
                    ))
                }
            }
        }
        .onAppear {
            loadDuplicateContacts()
        }
        .alert(
            BundleUtil.localizedString(forKey: "multi_device_new_linked_own_identity_in_contacts_title"),
            isPresented: $showOwnIdentityInContactsAlert
        ) {
            Button(BundleUtil.localizedString(forKey: "multi_device_new_linked_show_contact_button")) {
                guard let ownIdentityContact = businessInjector.entityManager.entityFetcher.contact(
                    for: businessInjector.myIdentityStore.identity
                ) else {
                    DDLogError("Unable to fetch own identity contact")
                    return
                }
                
                NotificationCenter.default.post(
                    name: .init(kNotificationShowContact),
                    object: nil,
                    userInfo: [kKeyContact: ownIdentityContact]
                )
            }
            
            Button("Cancel", role: .cancel) {
                // no-op
            }
        } message: {
            Text(BundleUtil.localizedString(forKey: "multi_device_new_linked_own_identity_in_contacts_message"))
        }
        .sheet(isPresented: $showPasscodeView) {
            LockScreenView(codeEnteredCorrectly: {
                // Dismissing the sheet explicitly here breaks the showing of the wizard. The dismissal might only work
                // because the next sheet is presented and SwiftUI currently only allows one sheet to be presented at
                // the same time. So this might break when this changes.
                showWizard = true
            }, cancelled: nil)
                .edgesIgnoringSafeArea(.bottom)
        }
    }

    private func loadDuplicateContacts() {
        var duplicates: NSSet?
        businessInjector.entityManager.entityFetcher.hasDuplicateContacts(
            withDuplicateIdentities: &duplicates
        )
        
        duplicateContactIdentities = Array(duplicates as? Set<String> ?? [])
    }
}

struct DisabledMultiDeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DisabledMultiDeviceListView(showWizard: .constant(false))
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
                    Text(
                        device.platformDetails ?? BundleUtil
                            .localizedString(forKey: "multi_device_new_linked_device_list_no_platform_details")
                    )

                    Text(String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "multi_device_new_linked_device_list_last_active"),
                        DateFormatter.relativeLongStyleDateShortStyleTime(device.lastLoginAt)
                    ))
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
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
