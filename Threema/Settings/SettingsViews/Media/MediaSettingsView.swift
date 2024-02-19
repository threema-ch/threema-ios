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
                        cellTitle: "settings_media_image_size_title".localized,
                        accessoryText: imageSize.rawValue.localized
                    )
                }

                NavigationLink {
                    VideoQualityPickerView(selectionItem: $videoQuality)
                        .environmentObject(settingsStore)
                } label: {
                    SettingsListItemView(
                        cellTitle: "settings_media_video_quality_title".localized,
                        accessoryText: videoQuality.rawValue.localized
                    )
                }

                Toggle(isOn: $settingsStore.autoSaveMedia) {
                    Text("settings_media_autosave_title".localized)
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
        .navigationBarTitle("settings_media_title".localized, displayMode: .inline)
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
            text += "disabled_by_device_policy".localized
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
                Text("image_resize_share_extension".localized)
            }
            .onChange(of: selectionItem) { newValue in
                settingsVM.imageSize = newValue.rawValue
            }
        }
        .navigationTitle("settings_media_image_size_title".localized)
    }

    private func pickerItem(_ option: ImageSenderItemSize) -> some View {
        VStack(alignment: .leading) {
            Text(BundleUtil.localizedString(forKey: option.rawValue))

            let resolution = Int(option.resolution)
            let footnote = option != .original ? String(
                format: "max_x_by_x_pixels".localized,
                resolution,
                resolution
            ) : "images are not scaled".localized

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

                            let duration = Int(option.maxDurationInMinutes)
                            if duration > 0 {
                                let footnote = String(
                                    format: "max_x_minutes".localized,
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
                Text("still_compressed_note".localized)
            }
            .onChange(of: selectionItem) { newValue in
                settingsVM.videoQuality = newValue.rawValue
            }
        }
        .navigationTitle("settings_media_video_quality_title".localized)
    }
}
