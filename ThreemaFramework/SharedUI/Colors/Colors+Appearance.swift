//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

// swiftformat:disable blankLinesAroundMark

import Foundation

// MARK: - Appearance
extension Colors {
    class func setupAppearance() {
        // MARK: Window
        update(window: UIWindow.appearance())
        
        // MARK: TabBar
        update(tabBar: UITabBar.appearance())
        
        // MARK: UINavigationBar
        update(navigationBar: UINavigationBar.appearance())
        
        // MARK: UIToolBar
        update(toolBar: UIToolbar.appearance())
        
        // MARK: UISearchBar
        update(searchBar: UISearchBar.appearance())
        
        // MARK: UIView
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .primary
        UIView.appearance(whenContainedInInstancesOf: [UIDocumentMenuViewController.self]).tintColor = .primary
        UIView.appearance(whenContainedInInstancesOf: [UIWindow.self, UIView.self]).tintColor = .primary
                
        // MARK: UITableView
        update(tableView: UITableView.appearance())
               
        // MARK: UITableViewCell
        update(cell: UITableViewCell.appearance())
        
        // MARK: UIButton
        UIButton.appearance(whenContainedInInstancesOf: [UIDocumentMenuViewController.self]).tintColor = .primary
                
        // MARK: UILabel
        // Do not change it for cells, because cells have their own appearance
        UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).textColor = Colors.textPlaceholder
            
        // MARK: UITextView
        UITextView.appearance().textColor = Colors.text
        UITextView.appearance().tintColor = .primary
        UITextView.appearance(whenContainedInInstancesOf: [PageContentViewController.self]).textColor = Colors.white
//        UITextView.appearance(whenContainedInInstancesOf: [PageContentViewController.self]).keyboardAppearance = .dark
        
        // MARK: TextField
        UITextField.appearance().textColor = Colors.text
        UITextField.appearance(whenContainedInInstancesOf: [PageContentViewController.self]).textColor = Colors.white
        UITextField.appearance(whenContainedInInstancesOf: [PageContentViewController.self]).keyboardAppearance = .dark
                
        // MARK: UISwitch
        update(switchAppearance: UISwitch.appearance())
        
        // MARK: UIBarButtonItem
        UIBarButtonItem.appearance().tintColor = .primary
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
            .setTitleTextAttributes([.foregroundColor: UIColor.primary], for: .normal)
        
        // MARK: UIProgressView
        UIProgressView.appearance().tintColor = .primary
               
        // MARK: UIActivityIndicatorView
        UIActivityIndicatorView.appearance().color = Colors.text
    }
}

// MARK: - Manual updates
public extension Colors {
    @objc class func updateKeyboardAppearance(for textInputTraits: UITextInputTraits) {
        if let textField = textInputTraits as? UITextField {
            switch theme {
            case .light, .undefined:
                textField.keyboardAppearance = .light
            case .dark:
                textField.keyboardAppearance = .dark
            }
            
            textField.textColor = Colors.text
            textField.tintColor = .primary
            
            if let placeholder = textField.attributedPlaceholder {
                let p = NSMutableAttributedString(attributedString: placeholder)
                p.addAttribute(
                    .foregroundColor,
                    value: Colors.textPlaceholder,
                    range: NSRange(location: 0, length: placeholder.length)
                )
                textField.attributedPlaceholder = p
            }
            textField.colorizeClearButton()
        }
        if let textView = textInputTraits as? UITextView {
            switch theme {
            case .light, .undefined:
                textView.keyboardAppearance = .light
            case .dark:
                textView.keyboardAppearance = .dark
            }
            textView.textColor = Colors.text
            textView.tintColor = .primary
        }
    }
    
    @objc class func update(tableView: UITableView) {
        tableView.sectionIndexColor = .primary
        tableView.separatorInsetReference = .fromAutomaticInsets
    }
    
    @objc class func update(cell: UITableViewCell, setBackgroundColor: Bool = true) {
        var textColor = Colors.text
        var detailTextColor = Colors.textLight
        
        if cell.accessibilityTraits == .notEnabled || !cell.isUserInteractionEnabled {
            textColor = Colors.textLight
            detailTextColor = Colors.textVeryLight
        }
        else if cell.accessibilityTraits == .button, cell.accessoryType != .disclosureIndicator,
                cell.accessoryType != .detailButton,
                !(cell.accessoryView?.isKind(of: UISwitch.self) ?? false) {
            textColor = .primary
            detailTextColor = Colors.textLight
        }
        
        // handle custom table cells
        setTextColor(textColor, in: cell.contentView)
        
        cell.textLabel?.textColor = textColor
        if let detailTextLabel = cell.detailTextLabel {
            detailTextLabel.textColor = detailTextColor
        }
        cell.tintColor = .primary
    }
    
    /// Check if a call or web session is active and return the correct appearance
    /// - Returns: Transparent or default UINavigationBarAppearance
    class func transparentNavigationBarAppearance() -> UINavigationBarAppearance {
        guard !VoIPHelper.shared().isCallActiveInBackground,
              !WCSessionHelper.isWCSessionConnected else {
            let defaultAppearance = defaultNavigationBarAppearance()
            defaultAppearance.shadowColor = .clear
            return defaultAppearance
        }
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        return appearance
    }

    @objc class func defaultNavigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = colorForNavigationBackground()
        return appearance
    }
    
    @objc class func colorForNavigationBackground() -> UIColor? {
        if VoIPHelper.shared().isCallActiveInBackground {
            return Colors.navigationBarCall
        }
        else if WCSessionHelper.isWCSessionConnected {
            return Colors.navigationBarWeb
        }
        return nil
    }
    
    @objc class func colorForBarTint() -> UIColor? {
        if VoIPHelper.shared().isCallActiveInBackground {
            return Colors.navigationBarCall
        }
        else if WCSessionHelper.isWCSessionConnected {
            return Colors.navigationBarWeb
        }
        return Colors.backgroundNavigationController
    }
            
    @objc class func update(navigationBar: UINavigationBar) {
        navigationBar.tintColor = .primary
        navigationBar.barTintColor = colorForBarTint()

        switch theme {
        case .light, .undefined:
            navigationBar.overrideUserInterfaceStyle = .light
        case .dark:
            navigationBar.overrideUserInterfaceStyle = .dark
        }
        navigationBar.standardAppearance = defaultNavigationBarAppearance()
        navigationBar.scrollEdgeAppearance = transparentNavigationBarAppearance()
    }
        
    @objc class func update(tabBar: UITabBar) {
        tabBar.tintColor = .primary
        tabBar.isTranslucent = true
        tabBar.isOpaque = false

        switch theme {
        case .light, .undefined:
            tabBar.barTintColor = .white
            tabBar.barStyle = .default
        case .dark:
            tabBar.barTintColor = .black
            tabBar.barStyle = .black
        }
        
        tabBar.scrollEdgeAppearance = tabBar.standardAppearance
    }
    
    @objc class func update(toolBar: UIToolbar) {
        toolBar.tintColor = .primary
        toolBar.barTintColor = Colors.backgroundToolbar
    }
    
    @objc class func update(window: UIWindow) {
        window.tintColor = .primary
        
        if !UserSettings.shared().useSystemTheme, window.overrideUserInterfaceStyle == .unspecified {
            window.overrideUserInterfaceStyle = theme == .dark ? .dark : .light
        }
        else {
            if UserSettings.shared().useSystemTheme, window.overrideUserInterfaceStyle != .unspecified {
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
    
    @objc class func update(searchBar: UISearchBar) {
        updateKeyboardAppearance(for: searchBar)
        
        switch theme {
        case .light, .undefined:
            searchBar.barStyle = .default
            UITextField.appearance().keyboardAppearance = .default
        case .dark:
            searchBar.barStyle = .black
            UITextField.appearance().keyboardAppearance = .dark
        }
        searchBar.isTranslucent = true
        
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
            .setTitleTextAttributes([.foregroundColor: UIColor.primary], for: .normal)
        
        searchBar.searchTextField.textColor = Colors.text
    }
    
    @objc class func update(switchAppearance: UISwitch) {
        switchAppearance.onTintColor = .primary
    }
        
    @objc class func setTextColor(_ color: UIColor, in parentView: UIView) {
        for view in parentView.subviews {
            
            if view is ContactNameLabel || view is UIButton {
                continue
            }
            
            if let themedCodeTableViewCell = view as? ThemedCodeTableViewCell {
                themedCodeTableViewCell.updateColors()
            }
            else if let label = view as? UILabel {
                setTextColor(color, label: label)
            }
            if let textView = view as? UITextView {
                setTextColor(color, textView: textView)
            }
            else if let textField = view as? UITextField {
                setTextColor(color, textField: textField)
            }
            else {
                setTextColor(color, in: view)
            }
        }
    }
    
    @objc class func setTextColor(_ color: UIColor, label: UILabel) {
        label.textColor = color
        label.highlightedTextColor = color
    }
    
    @objc class func setTextColor(_ color: UIColor, textView: UITextView) {
        textView.textColor = color
    }
    
    @objc class func setTextColor(_ color: UIColor, textField: UITextField) {
        textField.textColor = color
        textField.colorizeClearButton()
        
        if let placeholderText = textField.placeholder {
            textField.attributedPlaceholder = NSAttributedString(
                string: placeholderText,
                attributes: [.foregroundColor: Colors.textPlaceholder]
            )
        }
    }
}
