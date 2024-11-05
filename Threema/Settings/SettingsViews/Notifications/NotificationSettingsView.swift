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
import ThreemaMacros

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
                        
            Section(header: Text(#localize("settings_notifications_inapp_section"))) {

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
                    Text(#localize("settings_notifications_inapp_preview"))
                }
            }
            
            Section {
                Toggle(isOn: $settingsVM.inAppSounds) {
                    Text(#localize("settings_notifications_inapp_sounds"))
                }
                
                Toggle(isOn: $settingsVM.inAppVibrate) {
                    Text(#localize("settings_notifications_inapp_vibrate"))
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
                    Text(#localize("settings_notifications_push_preview"))
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
                Text(#localize("settings_notifications_push_section"))
            } footer: {
                VStack {
                    Text(LocalizedStringKey(String.localizedStringWithFormat(
                        #localize("settings_notification_type_preview_description"),
                        faqURLString
                    )))
                    
                    if disablePreviewToggle {
                        Text(#localize("disabled_by_device_policy"))
                    }
                }
            }
            
            Section {
                NavigationLink {
                    SoundPickerView(
                        selection: $settingsVM.pushSound,
                        title: #localize("settings_notifications_push_sound")
                    )
                } label: {
                    SettingsListItemView(
                        cellTitle: #localize("settings_notifications_push_sound"),
                        accessoryText: BundleUtil.localizedString(forKey: "sound_\(settingsVM.pushSound)")
                    )
                }
                
                NavigationLink {
                    SoundPickerView(
                        selection: $settingsVM.pushGroupSound,
                        title: #localize("settings_notifications_push_groupsound")
                    )
                } label: {
                    SettingsListItemView(
                        cellTitle: #localize("settings_notifications_push_groupsound"),
                        accessoryText: BundleUtil.localizedString(forKey: "sound_\(settingsVM.pushGroupSound)")
                    )
                }
            }

            // MARK: - DND
            
            if LicenseStore.requiresLicenseKey() {
                Section(
                    header: Text(#localize("settings_notifications_masterDnd_section_header")),
                    footer: Text(#localize("settings_notifications_masterDnd_section_footer"))
                ) {
                    
                    Toggle(isOn: $settingsVM.enableMasterDnd) {
                        Text(#localize("settings_notifications_masterDnd"))
                    }
                    
                    if settingsVM.enableMasterDnd {
                        
                        NavigationLink {
                            DayPickerView()
                                .environmentObject(settingsVM)
                        } label: {
                            SettingsListItemView(
                                cellTitle: #localize("settings_notifications_masterDnd_workingDays"),
                                accessoryText: workingDaysSummary()
                            )
                        }
                        
                        DatePicker(
                            #localize("settings_notifications_masterDnd_startTime"),
                            selection: $dndBegin,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .onChange(of: dndBegin) { _ in
                            didSetStartTime()
                        }
                        
                        DatePicker(
                            #localize("settings_notifications_masterDnd_endTime"),
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
                    #localize("settings_notification_iOS_settings"),
                    destination: URL(string: UIApplication.openSettingsURLString)!
                )
            }
        }
        .navigationBarTitle(
            #localize("settings_list_notifications_title"),
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
                    Text(BundleUtil.localizedString(forKey: "sound_\(sound)"))
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
            .navigationTitle(#localize("settings_notifications_masterDnd_workingDays"))
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
