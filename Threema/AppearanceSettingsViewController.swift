//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

import Foundation
import CocoaLumberjackSwift

class AppearanceSettingsViewController: ThemedTableViewController {
    
    @IBOutlet weak var showProfilePicturesSwitch: UISwitch!
    @IBOutlet weak var showGalleryPreviewSwitch: UISwitch!
    @IBOutlet weak var hideStaleContactsSwitch: UISwitch!
    @IBOutlet weak var systemThemeButton: UIButton!
    @IBOutlet weak var lightThemeButton: UIButton!
    @IBOutlet weak var darkThemeButton: UIButton!
    @IBOutlet weak var displayOrderValue: UILabel!
    @IBOutlet weak var previewLimitLabel: UILabel!
    @IBOutlet weak var previewLimitSlider: UISlider!
    
    @IBOutlet weak var systemStackView: UIStackView!
    
    @IBOutlet weak var systemThemeLabel: UILabel!
    @IBOutlet weak var lightThemeLabel: UILabel!
    @IBOutlet weak var darkThemeLabel: UILabel!
    @IBOutlet weak var hideStaleContactsLabel: UILabel!
    @IBOutlet weak var showProfilePicturesLabel: UILabel!
    @IBOutlet weak var displayOrderLabel: UILabel!
    @IBOutlet weak var showGalleryPreviewLabel: UILabel!
    
    @IBOutlet weak var themeCell: UITableViewCell!
    
    private var colorThemeObserver: NSObjectProtocol?
    
    deinit {
        if let observer = colorThemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        colorThemeObserver = NotificationCenter.default.addObserver(forName: Notification.Name(kNotificationColorThemeChanged), object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            switch Colors.getTheme() {
            case ColorThemeDark, ColorThemeDarkWork:
                self.systemThemeButton.layer.shadowColor = Colors.white()?.cgColor
                break
            case ColorThemeLight, ColorThemeLightWork, ColorThemeUndefined:
                self.systemThemeButton.layer.shadowColor = Colors.black()?.cgColor
                break
            default:
                self.systemThemeButton.layer.shadowColor = Colors.black()?.cgColor
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.updateView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        previewLimitSlider.isEnabled = showGalleryPreviewSwitch.isOn
    }
    
    func updateView() {
        darkThemeLabel.text = BundleUtil.localizedString(forKey: "settings_appearance_dark_theme")
        lightThemeLabel.text = BundleUtil.localizedString(forKey: "settings_appearance_light_theme")
        systemThemeLabel.text = BundleUtil.localizedString(forKey: "settings_appearance_system_theme")
        
        darkThemeButton.accessibilityLabel = BundleUtil.localizedString(forKey: "settings_appearance_dark_theme")
        lightThemeButton.accessibilityLabel = BundleUtil.localizedString(forKey: "settings_appearance_light_theme")
        systemThemeButton.accessibilityLabel = BundleUtil.localizedString(forKey: "settings_appearance_system_theme")
        
        hideStaleContactsLabel.text = BundleUtil.localizedString(forKey: "settings_appearance_hide_stale_contacts")
        showProfilePicturesLabel.text = BundleUtil.localizedString(forKey: "settings_appearance_show_profile_pictures")
        displayOrderLabel.text = BundleUtil.localizedString(forKey: "settings_appearance_display_order")
        showGalleryPreviewLabel.text = BundleUtil.localizedString(forKey: "settings_appearance_show_gallery_preview")
        
        showProfilePicturesSwitch.isOn = UserSettings.shared().showProfilePictures
        showGalleryPreviewSwitch.isOn = UserSettings.shared().showGalleryPreview
                
        darkThemeButton.layer.shadowColor = Colors.white()?.cgColor
        darkThemeButton.layer.shadowOffset = CGSize.init(width: 0, height: 0)
        darkThemeButton.layer.shadowRadius = 9.0
        
        lightThemeButton.layer.shadowColor = Colors.black()?.cgColor
        lightThemeButton.layer.shadowOffset = CGSize.init(width: 0, height: 0)
        lightThemeButton.layer.shadowRadius = 9.0
        
        switch Colors.getTheme() {
        case ColorThemeDark, ColorThemeDarkWork:
            systemThemeButton.layer.shadowColor = Colors.white()?.cgColor
            
            break
        case ColorThemeLight, ColorThemeLightWork, ColorThemeUndefined:
            systemThemeButton.layer.shadowColor = Colors.black()?.cgColor
            break
        default:
            systemThemeButton.layer.shadowColor = Colors.black()?.cgColor
        }
        systemThemeButton.layer.shadowOffset = CGSize.init(width: 0, height: 0)
        systemThemeButton.layer.shadowRadius = 9.0

        if LicenseStore.requiresLicenseKey() == false {
            lightThemeButton.setImage(BundleUtil.imageNamed("Light-Theme"), for: .normal)
            darkThemeButton.setImage(BundleUtil.imageNamed("Dark-Theme"), for: .normal)
            systemThemeButton.setImage(BundleUtil.imageNamed("System-Theme"), for: .normal)
        } else {
            lightThemeButton.setImage(BundleUtil.imageNamed("Light-Theme-Work"), for: .normal)
            darkThemeButton.setImage(BundleUtil.imageNamed("Dark-Theme-Work"), for: .normal)
            systemThemeButton.setImage(BundleUtil.imageNamed("System-Theme-Work"), for: .normal)
        }
        
        displayOrderValue.text = UserSettings.shared().displayOrderFirstName ? BundleUtil.localizedString(forKey: "SortOrder_Firstname") : BundleUtil.localizedString(forKey: "SortOrder_Lastname")
        
        hideStaleContactsSwitch.isOn = UserSettings.shared().hideStaleContacts
        
        previewLimitSlider.value = UserSettings.shared().previewLimit
        previewLimitLabel.text = String.init(format: BundleUtil.localizedString(forKey: "preview_limit"), previewLimitSlider.value)
        previewLimitLabel.isEnabled = showGalleryPreviewSwitch.isOn
        
        if #available(iOS 13.0, *) {
            systemStackView.isHidden = false
            if UserSettings.shared().useSystemTheme {
                lightThemeButton.layer.shadowOpacity = 0.0
                darkThemeButton.layer.shadowOpacity = 0.0
                systemThemeButton.layer.shadowOpacity = 1.0
                themeCell.accessibilityLabel = String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "settings_appearance_theme_selected"), BundleUtil.localizedString(forKey: "settings_appearance_system_theme"))
                systemThemeButton.accessibilityLabel = BundleUtil.localizedString(forKey: "settings_appearance_system_theme") + ", " + BundleUtil.localizedString(forKey: "settings_appearance_theme_active")
            } else {
                updateButtonShadowForCurrentTheme()
            }
        } else {
            systemStackView.isHidden = true
            updateButtonShadowForCurrentTheme()
        }
    }
    
    private func updateButtonShadowForCurrentTheme() {
        switch Colors.getTheme() {
        case ColorThemeDark, ColorThemeDarkWork:
            lightThemeButton.layer.shadowOpacity = 0.0
            darkThemeButton.layer.shadowOpacity = 1.0
            systemThemeButton.layer.shadowOpacity = 0.0
            themeCell.accessibilityLabel = String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "settings_appearance_theme_selected"), BundleUtil.localizedString(forKey: "settings_appearance_dark_theme"))
            darkThemeButton.accessibilityLabel = BundleUtil.localizedString(forKey: "settings_appearance_dark_theme") + ", " + BundleUtil.localizedString(forKey: "settings_appearance_theme_active")
            break
        case ColorThemeLight, ColorThemeLightWork, ColorThemeUndefined:
            lightThemeButton.layer.shadowOpacity = 1.0
            darkThemeButton.layer.shadowOpacity = 0.0
            systemThemeButton.layer.shadowOpacity = 0.0
            themeCell.accessibilityLabel = String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "settings_appearance_theme_selected"), BundleUtil.localizedString(forKey: "settings_appearance_light_theme"))
            lightThemeButton.accessibilityLabel = BundleUtil.localizedString(forKey: "settings_appearance_light_theme") + ", " + BundleUtil.localizedString(forKey: "settings_appearance_theme_active")
            break
        default:
            lightThemeButton.layer.shadowOpacity = 1.0
            darkThemeButton.layer.shadowOpacity = 0.0
            systemThemeButton.layer.shadowOpacity = 0.0
            themeCell.accessibilityLabel = String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "settings_appearance_theme_selected"), BundleUtil.localizedString(forKey: "settings_appearance_light_theme"))
            lightThemeButton.accessibilityLabel = BundleUtil.localizedString(forKey: "settings_appearance_light_theme") + ", " + BundleUtil.localizedString(forKey: "settings_appearance_theme_active")
        }
    }
}

extension AppearanceSettingsViewController {
        
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            return 230.0
        }
        if #available(iOS 11.0, *) {
            // do nothing
        } else {
            if indexPath.row == 3 {
                return 0
            }
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            return 230
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return BundleUtil.localizedString(forKey: "settings_appearance_theme_section")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return UserSettings.shared().hideStaleContacts ? BundleUtil.localizedString(forKey: "show_stale_contacts_on") : BundleUtil.localizedString(forKey: "show_stale_contacts_off")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension AppearanceSettingsViewController {
    
    @IBAction func systemThemeSelected(sender: UIButton) {
        UserSettings.shared()?.useSystemTheme = true
        
        darkThemeButton.layer.shadowOpacity = 0.0
        lightThemeButton.layer.shadowOpacity = 0.0
        systemThemeButton.layer.shadowOpacity = 1.0
        
        if #available(iOS 13.0, *) {
            AppDelegate.shared().window.overrideUserInterfaceStyle = .unspecified
            
            if self.traitCollection.userInterfaceStyle == .dark {
                if Colors.getTheme() != ColorThemeDark && Colors.getTheme() != ColorThemeDarkWork {
                    Colors.setTheme(LicenseStore.requiresLicenseKey() ? ColorThemeDarkWork : ColorThemeDark)
                }
            } else {
                if Colors.getTheme() != ColorThemeLight && Colors.getTheme() != ColorThemeLightWork {
                    Colors.setTheme(LicenseStore.requiresLicenseKey() ? ColorThemeLightWork : ColorThemeLight)
                }
            }
        }
    }
    
    @IBAction func lightThemeSelected(sender: UIButton) {
        UserSettings.shared().useSystemTheme = false
        switch Colors.getTheme() {
        case ColorThemeLight, ColorThemeLightWork:
            break
        case ColorThemeDark, ColorThemeDarkWork, ColorThemeUndefined:
            Colors.setTheme(LicenseStore.requiresLicenseKey() ? ColorThemeLightWork : ColorThemeLight)
            break
        default:
            Colors.setTheme(LicenseStore.requiresLicenseKey() ? ColorThemeLightWork : ColorThemeLight)
        }
        
        updateButtonShadowForCurrentTheme()
        
        if #available(iOS 13.0, *) {
            AppDelegate.shared()?.window.overrideUserInterfaceStyle = .light
        }
    }
    
    @IBAction func darkThemeSelected(sender: UIButton) {
        UserSettings.shared().useSystemTheme = false
        switch Colors.getTheme() {
        case ColorThemeDark, ColorThemeDarkWork:
            break
        case ColorThemeLight, ColorThemeLightWork, ColorThemeUndefined:
            Colors.setTheme(LicenseStore.requiresLicenseKey() ? ColorThemeDarkWork : ColorThemeDark)
            break
        default:
            Colors.setTheme(LicenseStore.requiresLicenseKey() ? ColorThemeDarkWork : ColorThemeDark)
        }
        updateButtonShadowForCurrentTheme()
        
        if #available(iOS 13.0, *) {
            AppDelegate.shared()?.window.overrideUserInterfaceStyle = .dark
        }
    }
    
    @IBAction func showProfilePicturesChanged(sender: UISwitch) {
        UserSettings.shared()?.showProfilePictures = showProfilePicturesSwitch.isOn
    }

    @IBAction func showGalleryPreviewChanged(sender: UISwitch) {
        UserSettings.shared()?.showGalleryPreview = showGalleryPreviewSwitch.isOn
        previewLimitLabel.isEnabled = showGalleryPreviewSwitch.isOn
        previewLimitSlider.isEnabled = showGalleryPreviewSwitch.isOn
    }

    @IBAction func hideStaleContactsChanged(sender: UISwitch) {
        UserSettings.shared()?.hideStaleContacts = hideStaleContactsSwitch.isOn
        tableView.reloadData()
    }

    @IBAction func previewLimitChanged(sender: UISlider) {
        let roundedValue = round(sender.value / 5) * 5
        sender.value = roundedValue
        previewLimitLabel.text = String.init(format: BundleUtil.localizedString(forKey: "preview_limit"), sender.value)
        UserSettings.shared()?.previewLimit = sender.value
    }
}
