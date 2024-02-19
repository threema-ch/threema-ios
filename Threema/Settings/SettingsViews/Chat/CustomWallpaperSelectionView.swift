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

struct CustomWallpaperSelectionView: View {
    let conversationID: NSManagedObjectID
    
    @EnvironmentObject var settingsVM: SettingsStore
    @State private var showingImagePicker = false

    @State var defaultSelected = false
    @State var defaultImage: Image?

    @State var customSelected = false
    @State var isSelectingCustom = false
    @State var customImage: Image?
    @State var selectedUIImage: UIImage?
    
    var onDismiss: () -> Void
    
    var body: some View {
        List {
            HStack(alignment: .center, spacing: 20) {
                WallpaperTypeView(
                    description: "settings_chat_wallpaper_default".localized,
                    image: $defaultImage, isSelected: $defaultSelected,
                    isSelectingCustom: $customSelected
                )
                .onTapGesture {
                    selectDefault()
                }
                WallpaperTypeView(
                    description: "settings_chat_wallpaper_custom".localized,
                    image: $customImage,
                    isSelected: $customSelected,
                    isSelectingCustom: $customSelected
                )
                .tint(UIColor.primary.color)
                .onTapGesture {
                    selectCustom()
                }
                .onChange(of: selectedUIImage) { _ in
                    loadImage()
                }
            }
        }
        .sheet(isPresented: $showingImagePicker, onDismiss: {
            loadImage()
        }, content: {
            SwiftUIImagePicker(image: $selectedUIImage)
        })
        .onAppear {
            if settingsVM.wallpaperStore.hasCustomWallpaper(for: conversationID) {
                selectedUIImage = settingsVM.wallpaperStore.wallpaper(for: conversationID)
                customImage = Image(uiImage: selectedUIImage!)
                customSelected = true
            }
            else {
                defaultSelected = true
            }
            
            if let currentDefault = settingsVM.wallpaperStore.currentDefaultWallpaper() {
                defaultImage = Image(uiImage: currentDefault)
            }
            else {
                defaultImage = Image(uiImage: UIImage(ciImage: CIImage.empty()))
            }
        }
        .onDisappear {
            onDismiss()
        }
    }
    
    // MARK: - Private Functions
    
    private func selectDefault() {
        settingsVM.wallpaperStore.deleteWallpaper(for: conversationID)

        withAnimation {
            defaultSelected = true
            isSelectingCustom = false
            customSelected = false
            customImage = nil
        }
    }
    
    private func selectCustom() {
        withAnimation {
            defaultSelected = false
            customSelected = true
            isSelectingCustom = true
            showingImagePicker = true
        }
    }
    
    private func loadImage() {
        isSelectingCustom = false

        guard let selectedUIImage else {
            selectDefault()
            return
        }
        withAnimation {
            customImage = Image(uiImage: selectedUIImage)
        }
        settingsVM.wallpaperStore.saveWallpaper(selectedUIImage, for: conversationID)
    }
}

public class CustomWallpaperSelectionViewController: UIViewController {
    
    private var viewController: UIViewController?
    
    public func customWallpaperSelectionView(
        conversationID: NSManagedObjectID,
        onDismiss: @escaping () -> Void
    ) -> UIViewController {
        let view = CustomWallpaperSelectionView(
            conversationID: conversationID,
            onDismiss: onDismiss
        ).environmentObject(SettingsStore())
        let hostingController = UIHostingController(rootView: view)
        let action = UIAction { _ in
            hostingController.dismiss(animated: true)
        }
        hostingController.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: action)
        hostingController.navigationItem.title = "settings_chat_wallpaper_title".localized

        return hostingController
    }
}
