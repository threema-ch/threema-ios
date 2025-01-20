//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
                        
        // MARK: UIButton
        UIButton.appearance(whenContainedInInstancesOf: [UIDocumentMenuViewController.self]).tintColor = .primary
                
        // MARK: UILabel
        // Do not change it for cells, because cells have their own appearance
        UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).textColor = UIColor.placeholderText
            
        // MARK: UITextView
        UITextView.appearance().textColor = .label
        UITextView.appearance().tintColor = .primary
        UITextView.appearance(whenContainedInInstancesOf: [PageContentViewController.self]).textColor = Colors.white
        
        // MARK: TextField
        UITextField.appearance().textColor = .label
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
        UIActivityIndicatorView.appearance().color = .label
    }
}

// MARK: - Manual updates
extension Colors {
    @objc public class func updateKeyboardAppearance(for textInputTraits: UITextInputTraits) {
        if let textField = textInputTraits as? UITextField {
            switch theme {
            case .light, .undefined:
                textField.keyboardAppearance = .light
            case .dark:
                textField.keyboardAppearance = .dark
            }
            
            textField.textColor = .label
            textField.tintColor = .primary
            
            if let placeholder = textField.attributedPlaceholder {
                let p = NSMutableAttributedString(attributedString: placeholder)
                p.addAttribute(
                    .foregroundColor,
                    value: UIColor.placeholderText,
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
            textView.textColor = .label
            textView.tintColor = .primary
        }
    }
    
    @objc public class func update(tableView: UITableView) {
        tableView.sectionIndexColor = .primary
        tableView.separatorInsetReference = .fromAutomaticInsets
    }
       
    /// Check if a call or web session is active and return the correct appearance
    /// - Returns: Transparent or default UINavigationBarAppearance
    public class func transparentNavigationBarAppearance() -> UINavigationBarAppearance {
        guard !NavigationBarPromptHandler.shouldShowPrompt() else {
            let defaultAppearance = defaultNavigationBarAppearance()
            defaultAppearance.shadowColor = .clear
            return defaultAppearance
        }
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        return appearance
    }

    @objc public class func defaultNavigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = colorForNavigationBackground()
        return appearance
    }
    
    @objc public class func colorForNavigationBackground() -> UIColor? {
        if NavigationBarPromptHandler.isCallActiveInBackground || NavigationBarPromptHandler.isGroupCallActive {
            return .navigationBarCall
        }
        else if NavigationBarPromptHandler.isWebActive {
            return .navigationBarWeb
        }
        return nil
    }
    
    @objc public class func colorForBarTint() -> UIColor? {
        if NavigationBarPromptHandler.isCallActiveInBackground || NavigationBarPromptHandler.isGroupCallActive {
            return .navigationBarCall
        }
        else if NavigationBarPromptHandler.isWebActive {
            return .navigationBarWeb
        }
        return Colors.backgroundNavigationController
    }
            
    @objc public class func update(navigationBar: UINavigationBar) {
        navigationBar.tintColor = .primary
        navigationBar.barTintColor = colorForBarTint()

        navigationBar.standardAppearance = defaultNavigationBarAppearance()
        navigationBar.scrollEdgeAppearance = transparentNavigationBarAppearance()
    }
        
    @objc public class func update(tabBar: UITabBar) {
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
    
    @objc public class func update(toolBar: UIToolbar) {
        toolBar.tintColor = .primary
        toolBar.barTintColor = Colors.backgroundToolbar
    }
    
    @objc public class func update(window: UIWindow) {
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
    
    @objc public class func update(searchBar: UISearchBar) {
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
        
        searchBar.searchTextField.textColor = .label
    }
    
    @objc public class func update(switchAppearance: UISwitch) {
        switchAppearance.onTintColor = .primary
    }
}
