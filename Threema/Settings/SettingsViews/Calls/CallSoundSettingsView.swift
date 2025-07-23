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

struct CallSoundSettingsView: View {
    @EnvironmentObject var settingsVM: SettingsStore
    
    private static let soundPreviewPlayer = SoundPreviewPlayer()
    
    private var soundList: [String] {
        var sounds = [
            "default",
            "threema_best",
            "threema_incom",
            "threema_xylo",
            "threema_goody",
            "threema_alphorn",
        ]

        // Work/OnPrem specific call sounds
        if TargetManager.isBusinessApp {
            sounds.append("threema_alarm")
        }

        return sounds
    }
    
    var body: some View {
        List {
            Picker("", selection: $settingsVM.voIPSound) {
                ForEach(soundList, id: \.self) { soundName in
                    Text(
                        soundName == "threema_best" ? TargetManager.appName : BundleUtil
                            .localizedString(forKey: "sound_\(soundName)")
                    )
                }
            }
        }
        .onChange(of: settingsVM.voIPSound, perform: { _ in
            CallSoundSettingsView.soundPreviewPlayer.playVoIPSound(voIPSoundName: settingsVM.voIPSound)
        })
        .onDisappear {
            CallSoundSettingsView.soundPreviewPlayer.stopPlaying()
        }
        .pickerStyle(.inline)
        .tint(.accentColor)
        .navigationTitle(#localize("settings_threema_calls_call_sound"))
    }
}

struct CallSoundSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CallSoundSettingsView()
            .tint(.accentColor)
            .environmentObject(BusinessInjector.ui.settingsStore as! SettingsStore)
    }
}
