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
import ThreemaFramework

struct ChatSettingsView: View {
    @ObservedObject var settingsVM: SettingsStore
    
    var body: some View {
        List {
            // MARK: - Wallpaper
    
            WallpaperSectionView(settingsVM: settingsVM)
            
            // MARK: - Chat

            Section {
                Toggle(isOn: $settingsVM.useBigEmojis) {
                    Text(BundleUtil.localizedString(forKey: "settings_chat_bigger_emojis"))
                }
                Toggle(isOn: $settingsVM.sendMessageFeedback) {
                    Text(BundleUtil.localizedString(forKey: "settings_chat_send_message_feedback"))
                }
            }
        }
        .navigationBarTitle(BundleUtil.localizedString(forKey: "settings_chat"), displayMode: .inline)
        .tint(UIColor.primary.color)
    }
}

struct ChatSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatSettingsView(settingsVM: SettingsStore())
    }
}

// MARK: - WallpaperSectionView

struct WallpaperSectionView: View {
    @ObservedObject var settingsVM: SettingsStore
    @State private var showingImagePicker = false
    @State private var showDeleteAlert = false
    
    @State var emptySelected = false
    @State var emptyImage: Image? = Image(uiImage: UIImage(ciImage: CIImage.empty()))

    @State var threemaSelected = false
    @State var threemaImage: Image? = Image(uiImage: WallpaperStore.shared.defaultWallPaper)

    @State var customSelected = false
    @State var isSelectingCustom = false
    @State var customImage: Image?
    @State var selectedUIImage: UIImage?
    
    var body: some View {
        
        Section(header: Text(BundleUtil.localizedString(forKey: "settings_chat_wallpaper_title"))) {
            HStack(alignment: .center, spacing: 20) {
                WallpaperTypeView(
                    description: BundleUtil.localizedString(forKey: "settings_chat_wallpaper_empty"),
                    image: $emptyImage,
                    isSelected: $emptySelected,
                    isSelectingCustom: $isSelectingCustom
                )
                .onTapGesture {
                    selectEmpty()
                }
                
                WallpaperTypeView(
                    description: "Threema",
                    image: $threemaImage,
                    isSelected: $threemaSelected,
                    isSelectingCustom: $isSelectingCustom
                )
                .onTapGesture {
                    selectThreema()
                }
                
                WallpaperTypeView(
                    description: BundleUtil.localizedString(forKey: "settings_chat_wallpaper_custom"),
                    image: $customImage,
                    isSelected: $customSelected,
                    isSelectingCustom: $isSelectingCustom
                )
                .onTapGesture {
                    selectCustom()
                }
                .onChange(of: selectedUIImage) { image in
                    guard image != nil else {
                        return
                    }
                    
                    loadImage()
                }
            }
            .edgesIgnoringSafeArea(.leading)
            
            HStack {
                Spacer()
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_chat_wallpaper_reset"))
                }
                Spacer()
            }
        }
        
        .alert(isPresented: $showDeleteAlert, content: {
            Alert(
                title: Text(BundleUtil.localizedString(forKey: "settings_chat_wallpaper_reset")),
                message: Text(BundleUtil.localizedString(forKey: "settings_chat_wallpaper_reset_all_alert")),
                primaryButton: .destructive(Text(
                    BundleUtil
                        .localizedString(forKey: "settings_privacy_TIRR_reset_alert_action")
                )) {
                    settingsVM.wallpaperStore.deleteAllCustom()
                },
                secondaryButton: .default(Text(BundleUtil.localizedString(forKey: "cancel"))) {
                    // Noop
                }
            )
        })
        
        .sheet(isPresented: $showingImagePicker, onDismiss: {
            loadImage()
        }, content: {
            SwiftUIImagePicker(image: $selectedUIImage)
        })
        
        .onAppear {
            if settingsVM.wallpaperStore.defaultIsEmptyWallpaper() {
                emptySelected = true
                customImage = nil
            }
            else if settingsVM.wallpaperStore.defaultIsThreemaWallpaper() {
                threemaSelected = true
                customImage = nil
            }
            else {
                selectedUIImage = settingsVM.wallpaperStore.currentDefaultWallpaper()
                customImage = Image(uiImage: selectedUIImage!)
                customSelected = true
            }
        }
    }
    
    // MARK: - Private Functions
    
    private func selectEmpty() {
        settingsVM.wallpaperStore.saveDefaultWallpaper(nil)
        withAnimation {
            emptySelected = true
            threemaSelected = false
            isSelectingCustom = false
            customSelected = false
            selectedUIImage = nil
            customImage = nil
        }
    }
    
    private func selectThreema() {
        settingsVM.wallpaperStore.saveDefaultWallpaper(settingsVM.wallpaperStore.defaultWallPaper)

        withAnimation {
            emptySelected = false
            threemaSelected = true
            isSelectingCustom = false
            customSelected = false
            selectedUIImage = nil
            customImage = nil
        }
    }
    
    private func selectCustom() {
        withAnimation {
            emptySelected = false
            threemaSelected = false
            isSelectingCustom = true
            customSelected = true
            showingImagePicker = true
        }
    }
    
    private func loadImage() {
        isSelectingCustom = false

        guard let selectedUIImage else {
            if LicenseStore.requiresLicenseKey() {
                selectEmpty()
            }
            else {
                selectThreema()
            }
            return
        }
        
        withAnimation {
            customImage = Image(uiImage: selectedUIImage)
        }
        settingsVM.wallpaperStore.saveDefaultWallpaper(selectedUIImage)
    }
}

// MARK: - WallpaperTypeView

struct WallpaperTypeView: View {
    var description: String
    @Binding var image: Image?
    @Binding var isSelected: Bool
    @Binding var isSelectingCustom: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 80, height: 150)
                .background {
                  
                    if image != nil {
                        image!
                            .resizable()
                            .scaledToFill()
                            .cornerRadius(15)
                    }
                    else if isSelectingCustom, image == nil {
                        ProgressView()
                    }
                    else {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(25)
                            .foregroundColor(UIColor.primary.color)
                    }
                }
                .cornerRadius(15)
                .clipped()
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            Color(uiColor: isSelected ? UIColor.primary : .tertiaryLabel),
                            lineWidth: 2
                        )
                }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.large)
                    .foregroundColor(UIColor.primary.color)
            }
            else {
                Image(systemName: "circle")
                    .imageScale(.large)
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity)
    }
}
