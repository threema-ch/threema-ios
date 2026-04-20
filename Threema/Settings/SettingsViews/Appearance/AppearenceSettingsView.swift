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
            viewModel.selectedTheme = theme
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
                                viewModel.selectedTheme == theme
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
