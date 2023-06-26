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

import SwiftUI

struct CallSettingsView: View {
    @EnvironmentObject var settingsVM: SettingsStore
    
    let mdmSetup = MDMSetup(setup: false)

    var body: some View {
        List {
            Section {
                Toggle(isOn: $settingsVM.enableThreemaCall.animation()) {
                    Text(BundleUtil.localizedString(forKey: "settings_threema_calls_enable_calls"))
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_CALLS) ?? false)
            }
            
            if settingsVM.enableThreemaCall {
                Section {
                    NavigationLink {
                        CallSoundSettingsView()
                    } label: {
                        HStack {
                            Text(BundleUtil.localizedString(forKey: "settings_threema_calls_call_sound"))
                            Spacer()
                            Text(BundleUtil.localizedString(forKey: "sound_\(settingsVM.voIPSound)"))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $settingsVM.alwaysRelayCalls.animation()) {
                        Text(BundleUtil.localizedString(forKey: "settings_threema_calls_always_relay_calls"))
                    }
                } footer: {
                    Text(hideVoIPIPFooter())
                }
                
                Section {
                    Toggle(isOn: $settingsVM.includeCallsInRecents.animation()) {
                        Text(BundleUtil.localizedString(forKey: "settings_threema_calls_callkit"))
                    }
                } footer: {
                    if settingsVM.includeCallsInRecents {
                        Text(
                            BundleUtil
                                .localizedString(forKey: "settings_threema_voip_include_call_in_recents_footer_on")
                        )
                    }
                    else {
                        Text(
                            BundleUtil
                                .localizedString(forKey: "settings_threema_voip_include_call_in_recents_footer_off")
                        )
                    }
                }
                
                Section {
                    Toggle(isOn: $settingsVM.enableVideoCall.animation()) {
                        Text(BundleUtil.localizedString(forKey: "settings_threema_calls_allow_video_calls"))
                    }
                    .disabled(mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_VIDEO_CALLS) ?? false)
                    
                    if settingsVM.enableVideoCall {
                        NavigationLink {
                            VideoCallQualitySelectionView()
                        } label: {
                            HStack {
                                Text(BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile"))
                                    .layoutPriority(1.0)
                                Spacer()
                                Text(CallsignalingProtocol.currentThreemaVideoCallQualitySettingTitle())
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(BundleUtil.localizedString(forKey: "settings_threema_calls_video_section"))
                } footer: {
                    if settingsVM.enableVideoCall {
                        Text(BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_footer"))
                    }
                }
            }
        }
        .navigationTitle(BundleUtil.localizedString(forKey: "settings_threema_calls"))
        .tint(UIColor.primary.color)
        .environmentObject(SettingsStore())
    }
    
    // MARK: - Private Functions

    private func hideVoIPIPFooter() -> String {
        if ThreemaApp.current == .onPrem {
            if settingsVM.alwaysRelayCalls {
                return BundleUtil.localizedString(forKey: "settings_threema_calls_onprem_hide_voip_call_ip_footer_on")
            }
            else {
                return BundleUtil.localizedString(forKey: "settings_threema_calls_onprem_hide_voip_call_ip_footer_off")
            }
        }
        else {
            if settingsVM.alwaysRelayCalls {
                return BundleUtil.localizedString(forKey: "settings_threema_calls_hide_voip_call_ip_footer_on")
            }
            else {
                return BundleUtil.localizedString(forKey: "settings_threema_calls_hide_voip_call_ip_footer_off")
            }
        }
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
        .environmentObject(SettingsStore())
    }
}
