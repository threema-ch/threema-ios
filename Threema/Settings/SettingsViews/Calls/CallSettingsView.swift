import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct CallSettingsView: View {
    
    @EnvironmentObject var settingsVM: SettingsStore

    let mdmSetup = MDMSetup()

    var body: some View {
        List {
            Section {
                Toggle(isOn: $settingsVM.enableThreemaCall) {
                    Text(String.localizedStringWithFormat(
                        #localize("settings_threema_calls_enable_calls"),
                        TargetManager.localizedAppName
                    ))
                }
                .disabled(
                    ThreemaEnvironment.supportsCallKit() ? mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_CALLS) ?? false : true
                )
            } footer: {
                if !ThreemaEnvironment.supportsCallKit() {
                    Text(String.localizedStringWithFormat(
                        #localize("settings_threema_voip_no_callkit_in_china_footer"),
                        TargetManager.localizedAppName
                    ))
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
                            accessoryText: settingsVM.voIPSound == "threema_best" ? TargetManager.appName : BundleUtil
                                .localizedString(forKey: "sound_\(settingsVM.voIPSound)")
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
                    Text(String.localizedStringWithFormat(
                        #localize("settings_threema_calls_enable_group_calls"),
                        TargetManager.localizedAppName
                    ))
                }
                .disabled(disableGroupCallToggle())
            } header: {
                Text(#localize("settings_threema_calls_group_calls_header"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(#localize("settings_threema_calls"))
        .tint(.accentColor)
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
        let onPrem = TargetManager.isOnPrem ? "_onprem" : ""
        let key = "settings_threema_calls\(onPrem)_hide_voip_call_ip_footer_\(setting)"
        
        return String.localizedStringWithFormat(BundleUtil.localizedString(forKey: key), TargetManager.appName)
    }
}

// MARK: - Preview

struct CallSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CallSettingsView()
                .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.accentColor)
        .environmentObject(BusinessInjector.ui.settingsStore as! SettingsStore)
    }
}
