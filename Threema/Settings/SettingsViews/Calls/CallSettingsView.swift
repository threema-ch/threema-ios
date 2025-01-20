//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct CallSettingsView: View {
    
    @EnvironmentObject var settingsVM: SettingsStore

    let mdmSetup = MDMSetup(setup: false)

    var body: some View {
        List {
            Section {
                Toggle(isOn: $settingsVM.enableThreemaCall) {
                    Text(#localize("settings_threema_calls_enable_calls"))
                }
                .disabled(
                    ThreemaEnvironment.supportsCallKit() ? mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_CALLS) ?? false : true
                )
            } footer: {
                if !ThreemaEnvironment.supportsCallKit() {
                    Text(#localize("settings_threema_voip_no_callkit_in_china_footer"))
                }
            }
            
            if settingsVM.enableThreemaCall {
                Section {
                    NavigationLink {
                        CallSoundSettingsView()
                            .environmentObject(settingsVM)
                    } label: {
                        SettingsListItemView(
                            cellTitle: #localize("settings_threema_calls_call_sound"),
                            accessoryText: BundleUtil.localizedString(forKey: "sound_\(settingsVM.voIPSound)")
                        )
                    }
                }
                
                Section {
                    Toggle(isOn: $settingsVM.alwaysRelayCalls) {
                        Text(#localize("settings_threema_calls_always_relay_calls"))
                    }
                } footer: {
                    Text(voIPFooterString())
                }
                
                Section {
                    Toggle(isOn: $settingsVM.includeCallsInRecents) {
                        Text(#localize("settings_threema_calls_callkit"))
                    }
                } footer: {
                    if settingsVM.includeCallsInRecents {
                        Text(#localize("settings_threema_voip_include_call_in_recents_footer_on"))
                    }
                    else {
                        Text(#localize("settings_threema_voip_include_call_in_recents_footer_off"))
                    }
                }
                
                Section {
                    Toggle(isOn: $settingsVM.enableVideoCall) {
                        Text(#localize("settings_threema_calls_allow_video_calls"))
                    }
                    .disabled(mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_VIDEO_CALLS) ?? false)
                    
                    if settingsVM.enableVideoCall {
                        NavigationLink {
                            VideoCallQualitySelectionView()
                                .environmentObject(settingsVM)
                        } label: {
                            HStack {
                                Text(#localize("settings_threema_calls_video_quality_profile"))
                                    .layoutPriority(1.0)
                                Spacer()
                                Text(CallsignalingProtocol.currentThreemaVideoCallQualitySettingTitle())
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(#localize("settings_threema_calls_video_section"))
                } footer: {
                    if settingsVM.enableVideoCall {
                        Text(#localize("settings_threema_calls_video_quality_profile_footer"))
                    }
                }
            }
            
            Section {
                Toggle(isOn: $settingsVM.enableThreemaGroupCalls) {
                    Text(#localize("settings_threema_calls_enable_group_calls"))
                }
                .disabled(disableGroupCallToggle())
            } header: {
                Text(#localize("settings_threema_calls_group_calls_header"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(#localize("settings_threema_calls"))
        .tint(UIColor.primary.color)
    }
    
    private func disableGroupCallToggle() -> Bool {
        // If there is a value for MDM_KEY_DISABLE_CALLS, we need to check if it is true
        if mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_CALLS) ?? false {
            // If calls are disabled, group calls will be disabled too
            if mdmSetup?.disableCalls() ?? false {
                return true
            }
            // If calls are enabled, we still need to check the MDM_KEY_DISABLE_GROUP_CALLS
            else if mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_GROUP_CALLS) ?? false {
                return true
            }
        }
        
        // Else we only check if there is a value for MDM_KEY_DISABLE_GROUP_CALLS
        else if mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_GROUP_CALLS) ?? false {
            return true
        }
        return false
    }
    
    // MARK: - Private Functions

    private func voIPFooterString() -> String {
        let setting = settingsVM.alwaysRelayCalls ? "on" : "off"
        let onPrem = ThreemaApp.current == .onPrem ? "_onprem" : ""
        return BundleUtil.localizedString(forKey: "settings_threema_calls\(onPrem)_hide_voip_call_ip_footer_\(setting)")
    }
}

// MARK: - Preview

struct CallSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CallSettingsView()
                .navigationBarTitleDisplayMode(.inline)
        }
        .tint(UIColor.primary.color)
        .environmentObject(BusinessInjector().settingsStore as! SettingsStore)
    }
}
