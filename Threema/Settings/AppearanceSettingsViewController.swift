//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import SwiftUI
import ThreemaMacros

class AppearanceSettingsViewController: ThemedTableViewController {
    
    @IBOutlet var showProfilePicturesSwitch: UISwitch!
    @IBOutlet var showGalleryPreviewSwitch: UISwitch!
    @IBOutlet var hideStaleContactsSwitch: UISwitch!
    @IBOutlet var systemThemeButton: UIButton!
    @IBOutlet var lightThemeButton: UIButton!
    @IBOutlet var darkThemeButton: UIButton!
    @IBOutlet var displayOrderValue: UILabel!
    @IBOutlet var previewLimitLabel: UILabel!
    @IBOutlet var previewLimitSlider: UISlider!
    
    @IBOutlet var systemStackView: UIStackView!
    
    @IBOutlet var systemThemeLabel: UILabel!
    @IBOutlet var lightThemeLabel: UILabel!
    @IBOutlet var darkThemeLabel: UILabel!
    @IBOutlet var hideStaleContactsLabel: UILabel!
    @IBOutlet var showProfilePicturesLabel: UILabel!
    @IBOutlet var displayOrderLabel: UILabel!
    @IBOutlet var showGalleryPreviewLabel: UILabel!
    @IBOutlet var appIconLabel: UILabel!

    @IBOutlet var themeCell: UITableViewCell!
    @IBOutlet var AppIconCell: UITableViewCell!

    private var colorThemeObserver: NSObjectProtocol?
    
    deinit {
        if let observer = colorThemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        colorThemeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(kNotificationColorThemeChanged),
            object: nil,
            queue: nil
        ) { _ in
            super.refresh()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        previewLimitSlider.isEnabled = showGalleryPreviewSwitch.isOn
    }
    
    func updateView() {
        darkThemeLabel.text = #localize("settings_appearance_dark_theme")
        lightThemeLabel.text = #localize("settings_appearance_light_theme")
        systemThemeLabel.text = #localize("settings_appearance_system_theme")
        
        darkThemeButton.accessibilityLabel = #localize("settings_appearance_dark_theme")
        lightThemeButton.accessibilityLabel = #localize("settings_appearance_light_theme")
        systemThemeButton.accessibilityLabel = #localize("settings_appearance_system_theme")
        
        hideStaleContactsLabel.text = #localize("settings_appearance_hide_stale_contacts")
        showProfilePicturesLabel.text = #localize("settings_appearance_show_profile_pictures")
        displayOrderLabel.text = #localize("settings_appearance_display_order")
        showGalleryPreviewLabel.text = #localize("settings_appearance_show_gallery_preview")
        
        showProfilePicturesSwitch.isOn = UserSettings.shared().showProfilePictures
        showGalleryPreviewSwitch.isOn = UserSettings.shared().showGalleryPreview
  
        let padding: CGFloat = 2
        let inset = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        
        darkThemeButton.contentEdgeInsets = inset
        lightThemeButton.contentEdgeInsets = inset
        systemThemeButton.contentEdgeInsets = inset
        
        darkThemeButton.layer.cornerRadius = 8.0
        darkThemeButton.layer.masksToBounds = true
        lightThemeButton.layer.cornerRadius = 8.0
        lightThemeButton.layer.masksToBounds = true
        systemThemeButton.layer.cornerRadius = 8.0
        systemThemeButton.layer.masksToBounds = true
        
        lightThemeButton.setImage(UIImage(resource: .themeLight), for: .normal)
        darkThemeButton.setImage(UIImage(resource: .themeDark), for: .normal)
        systemThemeButton.setImage(UIImage(resource: .themeSystem), for: .normal)
        
        lightThemeButton.imageView?.contentMode = .scaleAspectFit
        darkThemeButton.imageView?.contentMode = .scaleAspectFit
        systemThemeButton.imageView?.contentMode = .scaleAspectFit

        displayOrderValue.text = UserSettings.shared()
            .displayOrderFirstName ? #localize("SortOrder_Firstname") : #localize("SortOrder_Lastname")
        displayOrderValue.textColor = .secondaryLabel
        
        if let mdmSetup = MDMSetup(setup: false) {
            hideStaleContactsSwitch.isEnabled = !mdmSetup.disableHideStaleContacts()
        }
        else {
            hideStaleContactsSwitch.isEnabled = true
        }
        
        hideStaleContactsSwitch.isOn = UserSettings.shared().hideStaleContacts
        
        previewLimitSlider.value = UserSettings.shared().previewLimit
        previewLimitLabel.text = String.localizedStringWithFormat(
            #localize("preview_limit"),
            previewLimitSlider.value
        )
        previewLimitLabel.isEnabled = showGalleryPreviewSwitch.isOn
        
        systemStackView.isHidden = false
        if UserSettings.shared().useSystemTheme {
            lightThemeButton.applyDeselectStyle()
            darkThemeButton.applyDeselectStyle()
            systemThemeButton.applySelectedStyle()
            
            themeCell.accessibilityLabel = String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_system_theme")
            )
            systemThemeButton
                .accessibilityLabel = #localize("settings_appearance_system_theme") + ", " +
                #localize("settings_appearance_theme_active")
        }
        else {
            updateButtonSelectionForCurrentTheme()
        }
        
        appIconLabel.text = #localize("settings_appearance_hide_app_icon")
    }
    
    private func updateButtonSelectionForCurrentTheme() {
        switch Colors.theme {
        case .dark:
            lightThemeButton.applyDeselectStyle()
            darkThemeButton.applySelectedStyle()
            systemThemeButton.applyDeselectStyle()
            themeCell.accessibilityLabel = String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_dark_theme")
            )
            darkThemeButton
                .accessibilityLabel = #localize("settings_appearance_dark_theme") + ", " +
                #localize("settings_appearance_theme_active")
        case .light, .undefined:
            lightThemeButton.applySelectedStyle()
            darkThemeButton.applyDeselectStyle()
            systemThemeButton.applyDeselectStyle()
            themeCell.accessibilityLabel = String.localizedStringWithFormat(
                #localize("settings_appearance_theme_selected"),
                #localize("settings_appearance_light_theme")
            )
            lightThemeButton
                .accessibilityLabel = #localize("settings_appearance_light_theme") + ", " +
                #localize("settings_appearance_theme_active")
        }
    }
}

extension UIButton {
    fileprivate func applySelectedStyle() {
        UIView.animate(withDuration: 0.2) {
            self.layer.borderColor = UIColor.tintColor.cgColor
            self.layer.borderWidth = 2
        }
    }
    
    fileprivate func applyDeselectStyle() {
        UIView.animate(withDuration: 0.2) {
            self.layer.borderColor = UIColor.clear.cgColor
            self.layer.borderWidth = 0
        }
    }
}

extension AppearanceSettingsViewController {
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, indexPath.row == 0 {
            return 235.0
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, indexPath.row == 0 {
            return 235
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Special app icons
        if section == 1 {
            if TargetManager.current == .threema {
                return UITableView.automaticDimension
            }
            return 0
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Special app icons
        if section == 1 {
            if TargetManager.current == .threema {
                return UITableView.automaticDimension
            }
            return 0
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return #localize("settings_appearance_theme_section")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 2 {
            return UserSettings.shared()
                .hideStaleContacts ? String.localizedStringWithFormat(
                    #localize("show_stale_contacts_on"),
                    TargetManager.localizedAppName
                ) : String.localizedStringWithFormat(
                    #localize("show_stale_contacts_off"),
                    TargetManager.localizedAppName
                )
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            1
        case 1:
            // Special app icons
            if TargetManager.current == .threema {
                1
            }
            else {
                0
            }
        case 2:
            1
        case 3:
            2
        case 4:
            2
        default:
            0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 {
            let iconSettingsViewController = UIHostingController(rootView: AppIconSettingsView())
            navigationController?.pushViewController(iconSettingsViewController, animated: true)
        }
    }
}

extension AppearanceSettingsViewController {
    
    @IBAction func systemThemeSelected(sender: UIButton) {
        UserSettings.shared()?.useSystemTheme = true
        
        lightThemeButton.applyDeselectStyle()
        darkThemeButton.applyDeselectStyle()
        systemThemeButton.applySelectedStyle()
        
        AppDelegate.shared().window.overrideUserInterfaceStyle = .unspecified
        
        if traitCollection.userInterfaceStyle == .dark {
            if Colors.theme != .dark {
                Colors.theme = .dark
            }
        }
        else {
            if Colors.theme != .light {
                Colors.theme = .light
            }
        }
        NotificationPresenterWrapper.shared.colorChanged()
    }
    
    @IBAction func lightThemeSelected(sender: UIButton) {
        UserSettings.shared().useSystemTheme = false
        switch Colors.theme {
        case .light:
            break
        case .dark, .undefined:
            Colors.theme = .light
        }
        
        updateButtonSelectionForCurrentTheme()

        AppDelegate.shared()?.window.overrideUserInterfaceStyle = .light
        NotificationPresenterWrapper.shared.colorChanged()
    }
    
    @IBAction func darkThemeSelected(sender: UIButton) {
        UserSettings.shared().useSystemTheme = false
        switch Colors.theme {
        case .dark:
            break
        case .light, .undefined:
            Colors.theme = .dark
        }
        updateButtonSelectionForCurrentTheme()
        
        AppDelegate.shared()?.window.overrideUserInterfaceStyle = .dark
        NotificationPresenterWrapper.shared.colorChanged()
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
        previewLimitLabel.text = String.localizedStringWithFormat(
            #localize("preview_limit"),
            sender.value
        )
        UserSettings.shared()?.previewLimit = sender.value
    }
}

struct AppearanceSettingsViewControllerRepresentable: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        UIStoryboard(name: "SettingsStoryboard", bundle: nil)
            .instantiateViewController(identifier: "AppearanceSettingsViewController")
    }
}
