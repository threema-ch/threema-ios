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
import ThreemaFramework

struct NotificationSettingsView: View {
    
    @EnvironmentObject var settingsVM: SettingsStore

    @State var dndBegin = Date.now
    @State var dndEnd = Date.now
    
    let disablePreviewToggle = MDMSetup(setup: false).existsMdmKey(MDM_KEY_DISABLE_MESSAGE_PREVIEW)
    let faqURLString = BundleUtil.object(forInfoDictionaryKey: "ThreemaNotificationInfo") as! String

    typealias TimeOfDay = (hour: Int, minute: Int)
    
    var body: some View {
        List {
            // MARK: - In App
                        
            Section(header: Text("settings_notifications_inapp_section".localized)) {

                NotificationTypeNotificationView(
                    showPreview: $settingsVM.inAppPreview,
                    notificationType: NotificationType.complete,
                    cornerRadius: 20.0,
                    inApp: true
                )
                .padding(.top, 8)
                .listRowSeparator(.hidden)
                .accessibilityElement(children: .combine)
                
                Toggle(isOn: $settingsVM.inAppPreview) {
                    Text("settings_notifications_inapp_preview".localized)
                }
            }
            
            Section {
                Toggle(isOn: $settingsVM.inAppSounds) {
                    Text("settings_notifications_inapp_sounds".localized)
                }
                
                Toggle(isOn: $settingsVM.inAppVibrate) {
                    Text("settings_notifications_inapp_vibrate".localized)
                }
            }
            
            // MARK: - Push Notifications

            Section {
                NotificationTypeNotificationView(
                    showPreview: $settingsVM.pushShowPreview,
                    notificationType: settingsVM.notificationType,
                    cornerRadius: 20.0,
                    inApp: false
                )
                .padding(.top, 8)
                .listRowSeparator(.hidden)
                .accessibilityElement(children: .combine)

                Toggle(isOn: $settingsVM.pushShowPreview) {
                    Text("settings_notifications_push_preview".localized)
                }
                .disabled(disablePreviewToggle)
                
                ForEach(NotificationType.allCases, id: \.self) { notificationType in
                    NotificationTypeTitleView(
                        selectedType: $settingsVM.notificationType,
                        notificationType: notificationType
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            settingsVM.notificationType = notificationType
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                
            } header: {
                Text("settings_notifications_push_section".localized)
            } footer: {
                VStack {
                    Text(LocalizedStringKey(String.localizedStringWithFormat(
                        "settings_notification_type_preview_description".localized,
                        faqURLString
                    )))
                    
                    if disablePreviewToggle {
                        Text("disabled_by_device_policy".localized)
                    }
                }
            }
            
            Section {
                NavigationLink {
                    SoundPickerView(
                        selection: $settingsVM.pushSound,
                        title: "settings_notifications_push_sound".localized
                    )
                } label: {
                    SettingsListItemView(
                        cellTitle: "settings_notifications_push_sound".localized,
                        accessoryText: "sound_\(settingsVM.pushSound)".localized
                    )
                }
                
                NavigationLink {
                    SoundPickerView(
                        selection: $settingsVM.pushGroupSound,
                        title: "settings_notifications_push_groupsound".localized
                    )
                } label: {
                    SettingsListItemView(
                        cellTitle: "settings_notifications_push_groupsound".localized,
                        accessoryText: "sound_\(settingsVM.pushGroupSound)".localized
                    )
                }
            }

            // MARK: - DND
            
            if LicenseStore.requiresLicenseKey() {
                Section(
                    header: Text("settings_notifications_masterDnd_section_header".localized),
                    footer: Text("settings_notifications_masterDnd_section_footer".localized)
                ) {
                    
                    Toggle(isOn: $settingsVM.enableMasterDnd) {
                        Text("settings_notifications_masterDnd".localized)
                    }
                    
                    if settingsVM.enableMasterDnd {
                        
                        NavigationLink {
                            DayPickerView()
                                .environmentObject(settingsVM)
                        } label: {
                            SettingsListItemView(
                                cellTitle: "settings_notifications_masterDnd_workingDays".localized,
                                accessoryText: workingDaysSummary()
                            )
                        }
                        
                        DatePicker(
                            "settings_notifications_masterDnd_startTime".localized,
                            selection: $dndBegin,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .onChange(of: dndBegin) { _ in
                            didSetStartTime()
                        }
                        
                        DatePicker(
                            "settings_notifications_masterDnd_endTime".localized,
                            selection: $dndEnd,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .onChange(of: dndEnd) { _ in
                            didSetEndTime()
                        }
                        
                        .onAppear {
                            dndBegin = dateFromTimeString(timeString: settingsVM.masterDndStartTime ?? "00:00")
                            dndEnd = dateFromTimeString(timeString: settingsVM.masterDndEndTime ?? "00:00")
                        }
                    }
                }
            }
            
            // MARK: - System

            Section {
                Link(
                    "settings_notification_iOS_settings".localized,
                    destination: URL(string: UIApplication.openSettingsURLString)!
                )
            }
        }
        .navigationBarTitle(
            "settings_list_notifications_title".localized,
            displayMode: .inline
        )
        .tint(UIColor.primary.color)
    }
    
    // MARK: - Functions

    private func workingDaysSummary() -> String {
        guard !settingsVM.masterDndWorkingDays.isEmpty else {
            return ""
        }
        
        let sortedWorkingDays = settingsVM.masterDndWorkingDays.sorted { a, b -> Bool in
            var dayA = a
            var dayB = b
            
            if dayA < Calendar.current.firstWeekday {
                dayA += Calendar.current.weekdaySymbols.count
            }
            if dayB < Calendar.current.firstWeekday {
                dayB += Calendar.current.weekdaySymbols.count
            }
            
            if dayA < dayB {
                return true
            }
            else {
                return false
            }
        }
        
        var workingDayShortString = ""
        
        for dayNumber in sortedWorkingDays {
            if !workingDayShortString.isEmpty {
                workingDayShortString.append(", ")
            }
            workingDayShortString.append(Calendar.current.shortWeekdaySymbols[dayNumber - 1])
        }
        return workingDayShortString
    }
    
    private func didSetStartTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: dndBegin)
        let minute = calendar.component(.minute, from: dndBegin)
        let newTimeString = String(format: "%02d:%02d", hour, minute)
        
        settingsVM.masterDndStartTime = newTimeString

        if dndBegin > dndEnd {
            dndEnd = dndBegin
        }
    }
    
    private func didSetEndTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: dndEnd)
        let minute = calendar.component(.minute, from: dndEnd)
        let newTimeString = String(format: "%02d:%02d", hour, minute)
        
        if dndEnd > dndBegin {
            settingsVM.masterDndEndTime = newTimeString
        }
        else {
            dndEnd = dndBegin
        }
    }
    
    private func dateFromTimeString(timeString: String) -> Date {
        let components: [String] = timeString.components(separatedBy: ":")
        return Calendar.current.date(
            bySettingHour: Int(components[0])!,
            minute: Int(components[1])!,
            second: 0,
            of: Date()
        )!
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            
            NavigationView {
                NotificationSettingsView()
            }
            
            NavigationView {
                SoundPickerView(selection: .constant("default"), title: "Group Push Sound")
            }
        }
        .tint(UIColor.primary.color)
    }
}

// MARK: - SubViews

private struct SoundPickerView: View {
    
    @Binding var selection: String
    let sounds = PushSounds.all
    let title: String
    
    var body: some View {
        List {
            Picker("", selection: $selection) {
                ForEach(sounds, id: \.self) { sound in
                    Text("sound_\(sound)".localized)
                }
            }
            .onChange(of: selection, perform: { _ in
                playPushSound(withName: selection)
            })
            .pickerStyle(.inline)
        }
        .navigationBarTitle(title)
    }
    
    private func playPushSound(withName name: String) {
        
        guard name != "none" else {
            return
        }
        
        guard name != "default" else {
            AudioServicesPlayAlertSound(1007)
            return
        }
        
        guard let soundPath = BundleUtil.path(forResource: name, ofType: "caf") else {
            DDLogError("Unable to load sound file path for `\(name)`")
            return
        }
        
        let soundFileURL = URL(fileURLWithPath: soundPath)
        var soundID: SystemSoundID = 0
        
        func soundCompletionCallback(soundID: SystemSoundID, _: UnsafeMutableRawPointer?) {
            AudioServicesRemoveSystemSoundCompletion(soundID)
            AudioServicesDisposeSystemSoundID(soundID)
        }
        
        AudioServicesCreateSystemSoundID(soundFileURL as CFURL, &soundID)
        AudioServicesAddSystemSoundCompletion(soundID, nil, nil, soundCompletionCallback, nil)
        AudioServicesPlayAlertSound(soundID)
    }
}

private struct DayPickerView: View {
    
    @EnvironmentObject var settingsVM: SettingsStore
    var days: [String] = Calendar.current.weekdaySymbols
    
    var body: some View {
        List {
            ForEach(0..<days.count, id: \.self) { index in
                HStack {
                    Text(dayForIndex(index: index))
                    Spacer()
                    if showCheckmark(index: index) {
                        Image(systemName: "checkmark")
                            .foregroundColor(UIColor.primary.color)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    didTap(index: index)
                }
            }
            .navigationTitle("settings_notifications_masterDnd_workingDays".localized)
        }
    }
    
    func dayForIndex(index: Int) -> String {
        var row = index + Calendar.current.firstWeekday
        if row > days.count {
            row = row - days.count
        }
        return days[row - 1]
    }
    
    func didTap(index: Int) {
        var row = index + Calendar.current.firstWeekday
        if row > days.count {
            row = row - days.count
        }
        if settingsVM.masterDndWorkingDays.contains(row) {
            settingsVM.masterDndWorkingDays.remove(row)
        }
        else {
            settingsVM.masterDndWorkingDays.insert(row)
        }
    }
    
    func showCheckmark(index: Int) -> Bool {
        var row = index + Calendar.current.firstWeekday
        if row > days.count {
            row = row - days.count
        }
        return settingsVM.masterDndWorkingDays.contains(row)
    }
}
