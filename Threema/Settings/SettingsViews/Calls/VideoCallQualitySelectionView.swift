import SwiftUI
import ThreemaMacros

struct VideoCallQualitySelectionView: View {
    @EnvironmentObject var settingsVM: SettingsStore
    
    private let videoQualitySettings: [ThreemaVideoCallQualitySetting] = [
        ThreemaVideoCallQualitySettingAuto,
        ThreemaVideoCallQualitySettingLowDataConsumption,
        ThreemaVideoCallQualitySettingMaximumQuality,
    ]
    
    var body: some View {
        List {
            Section {
                Picker(selection: $settingsVM.threemaVideoCallQualitySetting) {
                    ForEach(videoQualitySettings, id: \.self) { qualitySettingItem in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CallsignalingProtocol.threemaVideoCallQualitySettingTitle(for: qualitySettingItem))
                            
                            Text(CallsignalingProtocol.threemaVideoCallQualitySettingSubtitle(for: qualitySettingItem))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                } label: {
                    EmptyView()
                }
                
            } footer: {
                Text(#localize("settings_threema_calls_video_quality_profile_footer"))
            }
        }
        .pickerStyle(.inline)
        .tint(.accentColor)
        .navigationTitle(#localize("settings_threema_calls_video_quality_profile"))
    }
}

// MARK: - ThreemaVideoCallQualitySetting + Hashable

extension ThreemaVideoCallQualitySetting: Hashable { }

struct VideoCallQualitySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCallQualitySelectionView()
    }
}
