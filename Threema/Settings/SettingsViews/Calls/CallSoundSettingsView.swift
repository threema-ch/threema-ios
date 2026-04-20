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
        .onChange(of: settingsVM.voIPSound) {
            CallSoundSettingsView.soundPreviewPlayer.playVoIPSound(voIPSoundName: settingsVM.voIPSound)
        }
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
