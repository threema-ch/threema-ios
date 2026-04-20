import SwiftUI
import ThreemaMacros

struct MediaSettingsView: View {
    private let mdmSetup = MDMSetup()

    @EnvironmentObject var settingsStore: SettingsStore

    @State private var imageSize: ImageSenderItemSize = .original
    @State private var videoQuality: VideoSenderItemQuality = .original
    @State private var footerText = ""

    var body: some View {
        List {
            Section(footer: Text(footerText)) {
                NavigationLink {
                    ImageSizePickerView(selectionItem: $imageSize)
                        .environmentObject(settingsStore)
                } label: {
                    SettingsListItemView(
                        cellTitle: #localize("settings_media_image_size_title"),
                        accessoryText: imageSize.rawValue.localized
                    )
                }

                NavigationLink {
                    VideoQualityPickerView(selectionItem: $videoQuality)
                        .environmentObject(settingsStore)
                } label: {
                    SettingsListItemView(
                        cellTitle: #localize("settings_media_video_quality_title"),
                        accessoryText: videoQuality.rawValue.localized
                    )
                }

                Toggle(isOn: $settingsStore.autoSaveMedia) {
                    Text(#localize("settings_media_autosave_title"))
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY) ?? false)
                .onChange(of: settingsStore.autoSaveMedia) {
                    updateFooter()
                }
            }
        }
        .onAppear {
            if let size = ImageSenderItemSize(rawValue: settingsStore.imageSize) {
                imageSize = size
            }
            if let quality = VideoSenderItemQuality(rawValue: settingsStore.videoQuality) {
                videoQuality = quality
            }
            updateFooter()
        }
        .navigationBarTitle(#localize("settings_media_title"), displayMode: .inline)
        .tint(.accentColor)
    }

    // MARK: - Private Functions
    
    private func updateFooter() {
        var text = settingsStore.autoSaveMedia ? #localize("settings_media_autosave_private_footer") : ""

        if let mdmSetup, mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY) {
            if !text.isEmpty {
                text += "\n\n"
            }
            text += #localize("disabled_by_device_policy")
        }

        footerText = text
    }
}

struct MediaSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MediaSettingsView()
        }
    }
}

private struct ImageSizePickerView: View {
    @EnvironmentObject var settingsVM: SettingsStore
    @Binding var selectionItem: ImageSenderItemSize

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selectionItem) {
                    ForEach(
                        ImageSenderItemSize.allCases,
                        id: \.self
                    ) { option in
                        pickerItem(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(#localize("image_resize_share_extension"))
            }
            .onChange(of: selectionItem) {
                settingsVM.imageSize = selectionItem.rawValue
            }
        }
        .navigationTitle(#localize("settings_media_image_size_title"))
    }

    private func pickerItem(_ option: ImageSenderItemSize) -> some View {
        VStack(alignment: .leading) {
            Text(BundleUtil.localizedString(forKey: option.rawValue))

            let resolution = Int(option.resolution)
            let footnote = option != .original ? String(
                format: #localize("max_x_by_x_pixels"),
                resolution,
                resolution
            ) : #localize("images are not scaled")

            Text(footnote)
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
}

private struct VideoQualityPickerView: View {
    @EnvironmentObject var settingsVM: SettingsStore
    @Binding var selectionItem: VideoSenderItemQuality

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selectionItem) {
                    ForEach(VideoSenderItemQuality.allCases, id: \.self) { option in
                        VStack(alignment: .leading) {
                            Text(BundleUtil.localizedString(forKey: option.rawValue))
                        }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(#localize("still_compressed_note"))
            }
            .onChange(of: selectionItem) {
                settingsVM.videoQuality = selectionItem.rawValue
            }
        }
        .navigationTitle(#localize("settings_media_video_quality_title"))
    }
}
