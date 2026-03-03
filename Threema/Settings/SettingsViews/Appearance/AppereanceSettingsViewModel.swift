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

import Combine
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class AppearanceSettingsViewModel: ObservableObject {

    // - MARK: Domain type

    enum Theme: String {
        case system, light, dark
    }

    enum DisplayOrder: Int, CaseIterable, Identifiable {
        case firstName = 0
        case lastName = 1

        var id: Int { rawValue }

        var localized: String {
            switch self {
            case .firstName: #localize("SortOrder_Firstname")
            case .lastName: #localize("SortOrder_Lastname")
            }
        }
    }

    // MARK: - State

    @Published var theme: Theme = .system
    @Published var showProfilePictures = true
    @Published var showGalleryPreview = true
    @Published var hideStaleContacts = false
    @Published var displayOrderFirstName = 0
    @Published var previewLimit: Float = 5.0
    @Published var staleContactsToggleEnabled = false

    // MARK: - Public properties

    let themeSectionLabel = #localize("settings_appearance_theme_section")
    let systemButtonTitle = #localize("settings_appearance_system_theme")
    let lightButtonTitle = #localize("settings_appearance_light_theme")
    let darkButtonTitle = #localize("settings_appearance_dark_theme")
    let inactiveToggleLabel = #localize("settings_appearance_hide_stale_contacts")
    let iconSettingsTitle = #localize("settings_appearance_hide_app_icon")
    let profileToggleTitle = #localize("settings_appearance_show_profile_pictures")
    let displayOrderLabel = #localize("settings_appearance_display_order")
    let galleryToggleTitle = #localize("settings_appearance_show_gallery_preview")

    var hideStaleContactsLabel: String {
        hideStaleContacts
            ? String.localizedStringWithFormat(#localize("show_stale_contacts_on"), TargetManager.localizedAppName)
            : String.localizedStringWithFormat(#localize("show_stale_contacts_off"), TargetManager.localizedAppName)
    }

    var displayOrderValue: String {
        switch displayOrderFirstName {
        case 0: DisplayOrder.firstName.localized
        case 1: DisplayOrder.lastName.localized
        default: ""
        }
    }

    var previewLimitText: String {
        String.localizedStringWithFormat(#localize("preview_limit"), previewLimit)
    }

    // MARK: - Private properties

    private var cancellables = Set<AnyCancellable>()
    private var settingsStore: SettingsStoreProtocol
    private lazy var appDelegate = AppDelegate.shared()

    // MARK: - Lifecycle

    init() {
        self.settingsStore = BusinessInjector.ui.settingsStore
        setupObservers()
    }

    // MARK: - Actions

    func refresh() {
        if settingsStore.useSystemTheme {
            theme = .system
        }
        else if Colors.theme == .dark {
            theme = .dark
        }
        else {
            theme = .light
        }
        showProfilePictures = settingsStore.showProfilePictures
        showGalleryPreview = settingsStore.showGalleryPreview
        hideStaleContacts = settingsStore.hideStaleContacts
        if settingsStore.displayOrderFirstName {
            displayOrderFirstName = 0
        }
        else {
            displayOrderFirstName = 1
        }
        previewLimit = settingsStore.previewLimit

        if let mdm = MDMSetup() {
            staleContactsToggleEnabled = !mdm.disableHideStaleContacts()
        }
        else {
            staleContactsToggleEnabled = false
        }
    }

    // MARK: - Helpers

    private func setupObservers() {
        $theme
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newTheme in
                self?.applyTheme(newTheme)
            }
            .store(in: &cancellables)

        $showProfilePictures
            .dropFirst()
            .sink { [weak self] in
                self?.settingsStore.showProfilePictures = $0
            }
            .store(in: &cancellables)

        $showGalleryPreview
            .dropFirst()
            .sink { [weak self] in
                self?.settingsStore.showGalleryPreview = $0
            }
            .store(in: &cancellables)

        $hideStaleContacts
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.hideStaleContacts = new
            }
            .store(in: &cancellables)

        $previewLimit
            .dropFirst()
            .map { round($0 / 5) * 5 }
            .sink { [weak self] value in
                self?.settingsStore.previewLimit = value
            }
            .store(in: &cancellables)

        $displayOrderFirstName
            .dropFirst()
            .sink { [weak self] value in
                if value == 0 {
                    self?.settingsStore.displayOrderFirstName = true
                }
                else {
                    self?.settingsStore.displayOrderFirstName = false
                }
            }
            .store(in: &cancellables)
    }

    private func applyTheme(_ theme: Theme) {
        switch theme {
        case .system:
            systemThemeSelected()
        case .light:
            lightThemeSelected()
        case .dark:
            darkThemeSelected()
        }

        NotificationPresenterWrapper.shared.colorChanged()
    }

    private func systemThemeSelected() {
        settingsStore.useSystemTheme = true
        appDelegate?.window.overrideUserInterfaceStyle = .unspecified

        if UITraitCollection.current.userInterfaceStyle == .dark {
            if Colors.theme != .dark {
                Colors.theme = .dark
            }
        }
        else {
            if Colors.theme != .light {
                Colors.theme = .light
            }
        }
    }

    private func lightThemeSelected() {
        settingsStore.useSystemTheme = false
        switch Colors.theme {
        case .light:
            break
        case .dark, .undefined:
            Colors.theme = .light
        }

        appDelegate?.window.overrideUserInterfaceStyle = .light
    }

    private func darkThemeSelected() {
        settingsStore.useSystemTheme = false
        switch Colors.theme {
        case .dark:
            break
        case .light, .undefined:
            Colors.theme = .dark
        }

        appDelegate?.window.overrideUserInterfaceStyle = .dark
    }
}

// MARK: - Accessibility

extension AppearanceSettingsViewModel {
    var themeSelectionAccessibilityLabel: String {
        if settingsStore.useSystemTheme {
            String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_system_theme")
            )
        }
        else if Colors.theme == .dark {
            String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_dark_theme")
            )
        }
        else {
            String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_light_theme")
            )
        }
    }

    var systemThemeButtonAccessibilityLabel: String {
        var value = #localize("settings_appearance_system_theme")
        if settingsStore.useSystemTheme {
            value = value + ", " + #localize("settings_appearance_theme_active")
        }
        return value
    }

    var lightThemeButtonAccessibilityLabel: String {
        var value = #localize("settings_appearance_light_theme")
        if !settingsStore.useSystemTheme, Colors.theme == .light {
            value = value + ", " + #localize("settings_appearance_theme_active")
        }
        return value
    }

    var darkThemeButtonAccessibilityLabel: String {
        var value = #localize("settings_appearance_dark_theme")
        if !settingsStore.useSystemTheme, Colors.theme == .dark {
            value = value + ", " + #localize("settings_appearance_theme_active")
        }
        return value
    }
}
