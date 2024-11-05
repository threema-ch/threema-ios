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
        .tint(UIColor.primary.color)
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
