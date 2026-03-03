//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

struct AppearanceSettingsView: View {
    @StateObject private var viewModel = AppearanceSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(
                header: Text(viewModel.themeSectionLabel)
                    .accessibilityLabel(viewModel.themeSelectionAccessibilityLabel)
            ) {
                HStack {
                    Spacer()
                    themeButton(title: viewModel.systemButtonTitle, theme: .system, image: .themeSystem)
                        .accessibilityLabel(viewModel.systemThemeButtonAccessibilityLabel)

                    themeButton(title: viewModel.lightButtonTitle, theme: .light, image: .themeLight)
                        .accessibilityLabel(viewModel.lightThemeButtonAccessibilityLabel)

                    themeButton(title: viewModel.darkButtonTitle, theme: .dark, image: .themeDark)
                        .accessibilityLabel(viewModel.darkThemeButtonAccessibilityLabel)
                    Spacer()
                }
            }

            Section(footer: Text(viewModel.hideStaleContactsLabel)) {
                Toggle(viewModel.inactiveToggleLabel, isOn: $viewModel.hideStaleContacts)
                    .disabled(!viewModel.staleContactsToggleEnabled)
            }

            if TargetManager.current == .threema {
                Section {
                    NavigationLink(destination: AppIconSettingsView()) {
                        Text(viewModel.iconSettingsTitle)
                    }
                }
            }

            Section {
                Toggle(viewModel.profileToggleTitle, isOn: $viewModel.showProfilePictures)

                Picker(viewModel.displayOrderLabel, selection: $viewModel.displayOrderFirstName) {
                    ForEach(AppearanceSettingsViewModel.DisplayOrder.allCases) { order in
                        Text(order.localized).tag(order.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(viewModel.galleryToggleTitle, isOn: $viewModel.showGalleryPreview)
                HStack(spacing: 16) {
                    Text(viewModel.previewLimitText)
                    Slider(value: $viewModel.previewLimit, in: 0...100, step: 5)
                }
                .disabled(!viewModel.showGalleryPreview)
            }
        }
        .onAppear {
            viewModel.refresh()
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(.accentColor)
    }

    @ViewBuilder
    private func themeButton(
        title: String,
        theme: AppearanceSettingsViewModel.Theme,
        image: ImageResource
    ) -> some View {
        Button {
            viewModel.theme = theme
        } label: {
            VStack {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                viewModel.theme == theme
                                    ? Color.accentColor
                                    : Color.clear, lineWidth: 2
                            )
                    )
                    .padding(8)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
