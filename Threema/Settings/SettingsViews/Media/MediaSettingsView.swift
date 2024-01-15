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

struct MediaSettingsView: View {
    private let mdmSetup = MDMSetup(setup: false)

    @StateObject var settingsStore = BusinessInjector().settingsStore as! SettingsStore

    @State private var imageSize: ImageSenderItemSize = .original
    @State private var videoQuality: VideoSenderItemQuality = .original
    @State private var footerText = ""

    var body: some View {
        List {
            Section(footer: Text(footerText)) {
                NavigationLink {
                    ImageSizePickerView(settingsVM: settingsStore, selectionItem: $imageSize)
                } label: {
                    HStack {
                        Text(BundleUtil.localizedString(forKey: "settings_media_image_size_title"))
                        Spacer()
                        Text(BundleUtil.localizedString(forKey: imageSize.rawValue))
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink {
                    VideoQualityPickerView(settingsVM: settingsStore, selectionItem: $videoQuality)
                } label: {
                    HStack {
                        Text(BundleUtil.localizedString(forKey: "settings_media_video_quality_title"))
                        Spacer()
                        Text(BundleUtil.localizedString(forKey: videoQuality.rawValue))
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settingsStore.autoSaveMedia) {
                    Text(BundleUtil.localizedString(forKey: "settings_media_autosave_title"))
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY) ?? false)
                .onChange(of: settingsStore.autoSaveMedia) { _ in
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
        .navigationBarTitle(BundleUtil.localizedString(forKey: "settings_media_title"), displayMode: .inline)
        .tint(UIColor.primary.color)
    }

    // MARK: - Private Functions
    
    private func updateFooter() {
        var text = settingsStore.autoSaveMedia ? BundleUtil
            .localizedString(forKey: "settings_media_autosave_private_footer") : ""

        if let mdmSetup, mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY) {
            if !text.isEmpty {
                text += "\n\n"
            }
            text += BundleUtil.localizedString(forKey: "disabled_by_device_policy")
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
    @ObservedObject var settingsVM: SettingsStore
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
                Text(BundleUtil.localizedString(forKey: "image_resize_share_extension"))
            }
            .onChange(of: selectionItem) { newValue in
                settingsVM.imageSize = newValue.rawValue
            }
        }
        .navigationTitle(BundleUtil.localizedString(forKey: "settings_media_image_size_title"))
    }

    private func pickerItem(_ option: ImageSenderItemSize) -> some View {
        VStack(alignment: .leading) {
            Text(BundleUtil.localizedString(forKey: option.rawValue))

            let resolution = Int(option.resolution)
            let footnote = option != .original ? String(
                format: BundleUtil.localizedString(forKey: "max_x_by_x_pixels"),
                resolution,
                resolution
            ) : BundleUtil.localizedString(forKey: "images are not scaled")

            Text(footnote)
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
}

private struct VideoQualityPickerView: View {
    @ObservedObject var settingsVM: SettingsStore
    @Binding var selectionItem: VideoSenderItemQuality

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selectionItem) {
                    ForEach(VideoSenderItemQuality.allCases, id: \.self) { option in
                        VStack(alignment: .leading) {
                            Text(BundleUtil.localizedString(forKey: option.rawValue))

                            let duration = Int(option.maxDurationInMinutes)
                            if duration > 0 {
                                let footnote = String(
                                    format: BundleUtil.localizedString(forKey: "max_x_minutes"),
                                    duration
                                )

                                Text(footnote)
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(BundleUtil.localizedString(forKey: "still_compressed_note"))
            }
            .onChange(of: selectionItem) { newValue in
                settingsVM.videoQuality = newValue.rawValue
            }
        }
        .navigationTitle(BundleUtil.localizedString(forKey: "settings_media_video_quality_title"))
    }
}
