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
import SwiftUI

// This is a WIP thus some things are not completed:
// TODO: (IOS-3939 & IOS-4001) UI might be improved when no device is linked, but MD is enabled

/// Enable Multi-Device with initial device or show existing linked devices
struct LinkedDevicesView: View {
    
    @EnvironmentObject private var settingsStore: SettingsStore
    
    @ObservedObject private var linkedDevicesViewModel = LinkedDevicesViewModel()
    @State private var showWizard = false
    
    var body: some View {
        // Stack so that we can add the view model, navigation title and sheet
        VStack {
            if settingsStore.isMultiDeviceRegistered {
                EnabledMultiDeviceListView(showWizard: $showWizard)
            }
            else {
                DisabledMultiDeviceListView(showWizard: $showWizard)
            }
        }
        .environmentObject(linkedDevicesViewModel)
        .navigationBarTitle(
            Text("settings_list_threema_desktop_title".localized),
            displayMode: .inline
        )
        .sheet(isPresented: $showWizard) {
            DeviceJoinView(showWizard: $showWizard)
        }
    }
}

#Preview("Main Linked Devices View") {
    // Even though "Add Device" for disabled MD will not be tinted in the preview it will be tinted when rendered inside
    // a running app (simulator & device)
    NavigationView {
        LinkedDevicesView()
            .environmentObject(BusinessInjector().settingsStore as! SettingsStore)
    }
}

// MARK: - Private Main Views

// MARK: EnabledMultiDeviceListView

@MainActor
private struct EnabledMultiDeviceListView: View {

    @Binding var showWizard: Bool
    
    @Environment(\.editMode) private var editMode
    @EnvironmentObject private var linkedDevicesViewModel: LinkedDevicesViewModel
    
    @State private var showRemovingError = false
    
    var body: some View {
        List {
            LinkedDevicesStateSections(
                showWizard: $showWizard,
                linkedDevicesState: $linkedDevicesViewModel.state,
                showRemovingError: $showRemovingError
            )
            RemoveAllDevicesSection()
        }
        .task {
            linkedDevicesViewModel.state = .refreshing
            await linkedDevicesViewModel.refresh()
        }
        .refreshable {
            await linkedDevicesViewModel.refresh()
        }
        .onChange(of: showWizard) { newValue in
            if newValue == false {
                linkedDevicesViewModel.state = .refreshing
                Task {
                    await linkedDevicesViewModel.refresh()
                }
            }
        }
        .onChange(of: linkedDevicesViewModel.state) { newValue in
            // Deactivate editing mode if state changes to no linked devices list
            switch newValue {
            case .refreshing, .error, .noLinkedDevices:
                editMode?.wrappedValue = .inactive
            case .linkedDevices:
                break
            }
        }
        .toolbar {
            if ThreemaEnvironment.allowMultipleLinkedDevices {
                // Allow editing if there's a list of linked devices
                EditButton()
                    .disabled(
                        linkedDevicesViewModel.state == .refreshing ||
                            linkedDevicesViewModel.state == .error ||
                            linkedDevicesViewModel.state == .noLinkedDevices
                    )
            }
        }
        .alert( // This needs to be here as subviews might get replaced/reloaded
            "Removing Linked Device Failed", // TODO: (IOS-4793) Localize
            isPresented: $showRemovingError
        ) {
            Button("ok".localized) {
                linkedDevicesViewModel.state = .refreshing
                Task {
                    await linkedDevicesViewModel.refresh()
                }
            }
        } message: {
            Text("multi_device_new_linked_device_error_message".localized)
        }
    }
}

// MARK: DisabledMultiDeviceListView

private struct DisabledMultiDeviceListView: View {
    
    @Binding var showWizard: Bool

    var body: some View {
        List {
            AddDeviceSection(showWizard: $showWizard)
        }
    }
}

// MARK: - Private Sections
 
// MARK: LinkedDevicesStateSections

private struct LinkedDevicesStateSections: View {
    
    @Binding var showWizard: Bool
    @Binding var linkedDevicesState: LinkedDevicesViewModel.State
    @Binding var showRemovingError: Bool
    
    var body: some View {
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
                Text("multi_device_new_linked_devices_failed_to_load".localized)
            }
            
        case let .linkedDevices(devicesInfo: devicesInfo):
            LinkedDevicesSection(devicesInfo: devicesInfo, showRemovingError: $showRemovingError)
            
            if ThreemaEnvironment.allowMultipleLinkedDevices {
                AddDeviceSection(showWizard: $showWizard)
            }
            
        case .noLinkedDevices:
            if ThreemaEnvironment.allowMultipleLinkedDevices {
                // TODO: (IOS-4001) This should not happen anymore
                AddDeviceSection(showWizard: $showWizard)
            }
            else {
                Section {
                    // No row
                } footer: {
                    // TODO: (IOS-3939 & IOS-4001) How do we handle if probably no device is linked, but md enabled?
                    Text(verbatim: String.localizedStringWithFormat(
                        "multi_device_new_linked_devices_no_other_device".localized,
                        "multi_device_new_linked_device_remove_all_button".localized
                    ))
                }
            }
        }
    }
}

#Preview("Linked Devices State Sections") {
    Group {
        List {
            LinkedDevicesStateSections(
                showWizard: .constant(false),
                linkedDevicesState: .constant(.refreshing),
                showRemovingError: .constant(false)
            )
        }

        List {
            LinkedDevicesStateSections(
                showWizard: .constant(false),
                linkedDevicesState: .constant(.error),
                showRemovingError: .constant(false)
            )
        }
        
        List {
            LinkedDevicesStateSections(
                showWizard: .constant(false),
                linkedDevicesState: .constant(.linkedDevices(devicesInfo: [
                    DeviceInfo(
                        deviceID: 1,
                        label: "iPhone 6.0 (6000)",
                        lastLoginAt: .now,
                        badge: nil,
                        platform: .ios,
                        platformDetails: "iPhone 15 Pro"
                    ),
                ])),
                showRemovingError: .constant(false)
            )
        }
        
        List {
            LinkedDevicesStateSections(
                showWizard: .constant(false),
                linkedDevicesState: .constant(.noLinkedDevices),
                showRemovingError: .constant(false)
            )
        }
    }
}

// MARK: LinkedDevicesSection

private struct LinkedDevicesSection: View {
    
    let devicesInfo: [DeviceInfo]
    
    @Binding var showRemovingError: Bool

    @EnvironmentObject private var linkedDevicesViewModel: LinkedDevicesViewModel
    
    // Our deletion implementation is a workaround to disable full sipe and customize the action text & image. At the
    // same time we want an easy way to allow an edit mode for better discoverability. If we just use
    // `onDelete(perform:)` we get an easy implementation of swipe-to-delete including a full swipe and an edit mode
    // for each cell. However, we cannot disable full-swipe-to-delete and customize the text & image shown in the
    // action (FB14535338). Our tests show that if we provide our own trailing swipe action we can override the full
    // swipe and add a custom text & icon. However, we need to keep `onDelete(perform:)` to allow deletion during edit
    // mode. In our tests the perform block is never actually called.
    // All tests where conducted with iOS 15.8.1, 16.7.2 & 17.5.1
    
    var body: some View {
        Section {
            ForEach(devicesInfo) { device in
                LinkedDeviceListView(device: device)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // We don't have a confirmation, but disallow a full swipe. Thus a swipe and tap is always
                        // needed
                        Button(role: .destructive) {
                            remove(device)
                        } label: {
                            // TODO: (IOS-4793) Localize
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .onDelete { _ in
                // This is needed to allow deletion in the edit mode. However, this should never be called, because the
                // swipe action above replaces the system delete swipe action and the swipe action will also be
                // tapped/called in editing mode.
                DDLogError("This should never be called")
                assertionFailure()
                showRemovingError = true
            }
        } footer: {
            if !ThreemaEnvironment.allowMultipleLinkedDevices {
                Text("multi_device_new_linked_devices_limitation_info".localized)
            }
        }
    }
    
    private func remove(_ device: DeviceInfo) {
        linkedDevicesViewModel.state = .refreshing
        Task(priority: .userInitiated) {
            do {
                try await linkedDevicesViewModel.remove(device)
                
                // TODO: (IOS-4001) Deactivate MD if there are no other devices.
                
                linkedDevicesViewModel.state = .refreshing
                await linkedDevicesViewModel.refresh()
            }
            catch {
                DDLogError("Error dropping devices: \(error)")
                
                showRemovingError = true
            }
        }
    }
}

#Preview("Swipeable Linked Devices") {
    let deviceInfos = [
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
            label: "Threema Desktop 2.0 (Preview 10)",
            lastLoginAt: .now,
            badge: nil,
            platform: .desktop,
            platformDetails: "Elektron 23"
        ),
    ]
    
    return List {
        LinkedDevicesSection(devicesInfo: deviceInfos, showRemovingError: .constant(false))
    }
}

// MARK: AddDeviceSection

private struct AddDeviceSection: View {
    
    // A bunch of checks happen in this view before the wizard is shown:
    // 1. If duplicate contacts are detected (`duplicateContactIdentities`) the button is disabled and the explanatory
    //    text lists the duplicate entries
    // 2. After tapping the button if a contact with my own identity is detected an alert is shown that allows to open
    //    the contact and delete it
    // 3. If a passcode is activated it is requested
    
    @Binding var showWizard: Bool
    
    @EnvironmentObject private var linkedDevicesViewModel: LinkedDevicesViewModel
    
    @State private var duplicateContactIdentities: [String] = []
    
    @State private var showOwnIdentityInContactsAlert = false
    @State private var showPasscodeView = false
    
    var body: some View {
        Section {
            Button {
                if linkedDevicesViewModel.businessInjector.entityManager.entityFetcher
                    .contactsContainOwnIdentity() != nil {
                    showOwnIdentityInContactsAlert = true
                }
                else if KKPasscodeLock.shared().isPasscodeRequired() {
                    showPasscodeView = true
                }
                else {
                    showWizard = true
                }
            } label: {
                Text("multi_device_new_linked_devices_add_button".localized)
            }
            .disabled(
                !duplicateContactIdentities.isEmpty ||
                    (linkedDevicesViewModel.deviceLimitReached && ThreemaEnvironment.allowMultipleLinkedDevices)
            )
        } footer: {
            if !duplicateContactIdentities.isEmpty {
                Text(verbatim: String.localizedStringWithFormat(
                    "multi_device_linked_duplicate_contacts_desc".localized,
                    ListFormatter.localizedString(byJoining: Array(duplicateContactIdentities))
                ))
            }
            else if linkedDevicesViewModel.deviceLimitReached, ThreemaEnvironment.allowMultipleLinkedDevices {
                // TODO: (IOS-4793) Localize strings
                if let numberOfDeviceSlots = linkedDevicesViewModel.businessInjector.multiDeviceManager
                    .maximumNumberOfDeviceSlots {
                    Text(
                        "Limit of \(numberOfDeviceSlots - 1) other devices reached. Remove a linked device to add a new device."
                    )
                }
                else {
                    Text("Limit of devices reached. Remove a linked device to add a new device.")
                }
            }
            else {
                // TODO: (IOS-4793) Update string
                Text(verbatim: """
                    \(String.localizedStringWithFormat(
                    "multi_device_new_linked_device_instructions".localized,
                    ThreemaApp.appName,
                    DeviceJoinManager.downloadURL
                    ))
                    
                    \(
                    ThreemaEnvironment.allowMultipleLinkedDevices ?
                    "IOS-4793" : "multi_device_new_linked_devices_limitation_info".localized
                    )
                    """)
            }
        }
        .onAppear {
            loadDuplicateContacts()
        }
        .alert(
            "multi_device_new_linked_own_identity_in_contacts_title".localized,
            isPresented: $showOwnIdentityInContactsAlert
        ) {
            Button("multi_device_new_linked_show_contact_button".localized) {
                guard let ownIdentityContact = linkedDevicesViewModel.businessInjector.entityManager.entityFetcher
                    .contact(
                        for: linkedDevicesViewModel.businessInjector.myIdentityStore.identity
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
            
            Button("cancel".localized, role: .cancel) {
                // no-op
            }
        } message: {
            Text("multi_device_new_linked_own_identity_in_contacts_message".localized)
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
        linkedDevicesViewModel.businessInjector.entityManager.entityFetcher.hasDuplicateContacts(
            withDuplicateIdentities: &duplicates
        )
        
        duplicateContactIdentities = Array(duplicates as? Set<String> ?? [])
    }
}

#Preview("Add Device Section") {
    NavigationView {
        List {
            AddDeviceSection(showWizard: .constant(false))
                .environmentObject(BusinessInjector().settingsStore as! SettingsStore)
                .environmentObject(LinkedDevicesViewModel())
        }
    }
    .tint(UIColor.primary.color)
}

// MARK: RemoveAllDevicesSection

private struct RemoveAllDevicesSection: View {
    
    @EnvironmentObject private var linkedDevicesViewModel: LinkedDevicesViewModel
    
    @State private var showDisableMultiDeviceConfirmation = false
    @State private var showRemovingError = false
    
    var body: some View {
        Section {
            Button(role: .destructive) {
                showDisableMultiDeviceConfirmation = true
            } label: {
                Text("multi_device_new_linked_device_remove_all_button".localized)
                    .frame(maxWidth: .infinity)
            }
            .disabled(linkedDevicesViewModel.state == .refreshing)
            .confirmationDialog(
                "multi_device_new_linked_device_remove_all_title".localized,
                isPresented: $showDisableMultiDeviceConfirmation
            ) {
                Button(
                    "multi_device_new_linked_device_remove_all_button".localized,
                    role: .destructive
                ) {
                    linkedDevicesViewModel.state = .refreshing
                    Task(priority: .userInitiated) {
                        do {
                            try await linkedDevicesViewModel.businessInjector.multiDeviceManager.disableMultiDevice()
                        }
                        catch {
                            DDLogError("Error disabling multi device: \(error)")
                            
                            showRemovingError = true
                        }
                    }
                }
            }
        }
        .alert(
            "multi_device_new_linked_device_remove_all_error_title".localized,
            isPresented: $showRemovingError
        ) {
            Button("ok".localized) {
                linkedDevicesViewModel.state = .refreshing
                Task {
                    await linkedDevicesViewModel.refresh()
                }
            }
        } message: {
            Text("multi_device_new_linked_device_error_message".localized)
        }
    }
}

#Preview("Remove All Devices Section") {
    let linkedDevicesViewModel = LinkedDevicesViewModel()
    linkedDevicesViewModel.state = .linkedDevices(devicesInfo: [])
    
    return List {
        RemoveAllDevicesSection()
            .environmentObject(linkedDevicesViewModel)
    }
}

// MARK: - Private List Views

private struct LinkedDeviceListView: View {
    
    @Environment(\.sizeCategory) private var sizeCategory: ContentSizeCategory
    
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
                        device.platformDetails ?? "multi_device_new_linked_device_list_no_platform_details".localized
                    )

                    // TODO: (IOS-4200) Fix properly
                    // Quick fix for current online state
                    if device.lastLoginAt.millisecondsSince1970 < 1 {
                        Text("multi_device_new_linked_device_list_currently_active".localized)
                    }
                    else {
                        Text(verbatim: String.localizedStringWithFormat(
                            "multi_device_new_linked_device_list_last_active".localized,
                            DateFormatter.relativeLongStyleDateShortStyleTime(device.lastLoginAt)
                        ))
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Linked Device") {
    let deviceInfos = [
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
            lastLoginAt: Date(timeIntervalSince1970: 0),
            badge: "Volatile Session",
            platform: .web,
            platformDetails: "Firefox 112.0.2"
        ),
        DeviceInfo(
            deviceID: 4,
            label: "Firefox 112.0.3",
            lastLoginAt: Date(timeIntervalSince1970: 1_500_000_000),
            badge: nil,
            platform: .web,
            platformDetails: nil
        ),
    ]
    
    return List(deviceInfos, id: \.deviceID) { device in
        LinkedDeviceListView(device: device)
    }
}
