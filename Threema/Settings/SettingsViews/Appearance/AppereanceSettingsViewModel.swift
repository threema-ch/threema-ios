import Combine
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class AppearanceSettingsViewModel: ObservableObject {

    // - MARK: Domain type

    enum Theme: String {
        case system, light, dark

        func getUserInterfaceStyle() -> UIUserInterfaceStyle {
            switch self {
            case .system: .unspecified
            case .light: .light
            case .dark: .dark
            }
        }

        func getColorsTheme() -> Colors.Theme {
            switch self {
            case .system: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
            case .light: .light
            case .dark: .dark
            }
        }
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

    @Published var selectedTheme: Theme = .system
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
        switch settingsStore.interfaceStyle {
        case UIUserInterfaceStyle.light.rawValue:
            selectedTheme = .light

        case UIUserInterfaceStyle.dark.rawValue:
            selectedTheme = .dark

        default:
            selectedTheme = .system
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
        $selectedTheme
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
        settingsStore.interfaceStyle = theme.getUserInterfaceStyle().rawValue
        Colors.theme = theme.getColorsTheme()
        Colors.update(window: appDelegate?.window ?? UIWindow.appearance())
        NotificationPresenterWrapper.shared.colorChanged()
    }
}

// MARK: - Accessibility

extension AppearanceSettingsViewModel {
    var themeSelectionAccessibilityLabel: String {
        switch selectedTheme {
        case .system:
            String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_system_theme")
            )
        case .dark:
            String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_dark_theme")
            )
        case .light:
            String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_light_theme")
            )
        }
    }

    var systemThemeButtonAccessibilityLabel: String {
        var value = #localize("settings_appearance_system_theme")
        if selectedTheme == .system {
            value = value + ", " + #localize("settings_appearance_theme_active")
        }
        return value
    }

    var lightThemeButtonAccessibilityLabel: String {
        var value = #localize("settings_appearance_light_theme")
        if selectedTheme == .light {
            value = value + ", " + #localize("settings_appearance_theme_active")
        }
        return value
    }

    var darkThemeButtonAccessibilityLabel: String {
        var value = #localize("settings_appearance_dark_theme")
        if selectedTheme == .dark {
            value = value + ", " + #localize("settings_appearance_theme_active")
        }
        return value
    }
}
