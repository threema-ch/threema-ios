// swiftformat:disable blankLinesAroundMark

import Foundation

// MARK: - Appearance
extension Colors {
    class func setupAppearance() {
        
        // MARK: Window
        update(window: UIWindow.appearance())
        
        // MARK: TabBar
        update(tabBar: UITabBar.appearance())
        
        // MARK: UIToolBar
        update(toolBar: UIToolbar.appearance())
        
        // MARK: UISearchBar
        update(searchBar: UISearchBar.appearance())
        
        // MARK: UIView
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .primary
        UIView.appearance(whenContainedInInstancesOf: [UIWindow.self, UIView.self]).tintColor = .primary
                                        
        // MARK: UILabel
        // Do not change it for cells, because cells have their own appearance
        UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).textColor = UIColor.placeholderText
            
        // MARK: UITextView
        UITextView.appearance().textColor = .label
        UITextView.appearance().tintColor = .primary
        
        // MARK: TextField
        UITextField.appearance().textColor = .label
        
        // MARK: UIBarButtonItem
        if #available(iOS 26.0, *) {
            UIBarButtonItem.appearance().tintColor = .label
            UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
                .setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        }
        else {
            UIBarButtonItem.appearance().tintColor = .primary
            UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
                .setTitleTextAttributes([.foregroundColor: UIColor.primary], for: .normal)
        }
        
        // MARK: UIProgressView
        UIProgressView.appearance().tintColor = .primary
               
        // MARK: UIActivityIndicatorView
        UIActivityIndicatorView.appearance().color = .label
        
        UISwitch.appearance().onTintColor = .primary
    }
}

// MARK: - Manual updates
extension Colors {
    @objc public class func updateKeyboardAppearance(for textInputTraits: AnyObject) {
        if let textField = textInputTraits as? UITextField {
            switch theme {
            case .light:
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
            case .light:
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
    
    @objc public class func colorForNavigationBackground() -> UIColor? {
        // We do no longer show navigation bar colors when using glass, because they cover the title label.
        if #available(iOS 26.0, *) {
            return nil
        }
        
        if NavigationBarPromptHandler.isCallActiveInBackground || NavigationBarPromptHandler.isGroupCallActive {
            return .navigationBarCall
        }
        else if NavigationBarPromptHandler.isWebActive {
            return .navigationBarWeb
        }
        
        return nil
    }
        
    @objc public class func update(tabBar: UITabBar) {
        tabBar.isTranslucent = true
        tabBar.isOpaque = false

        switch theme {
        case .light:
            tabBar.barTintColor = .white
            tabBar.barStyle = .default
        case .dark:
            tabBar.barTintColor = .black
            tabBar.barStyle = .black
        }
        
        tabBar.scrollEdgeAppearance = tabBar.standardAppearance
    }
    
    @objc public class func update(toolBar: UIToolbar) {
        toolBar.barTintColor = Colors.backgroundToolbar
    }
    
    @objc public class func update(window: UIWindow) {
        switch UserSettings.shared().interfaceStyle {
        case UIUserInterfaceStyle.light.rawValue:
            if window.overrideUserInterfaceStyle != .light {
                window.overrideUserInterfaceStyle = .light
            }

        case UIUserInterfaceStyle.dark.rawValue:
            if window.overrideUserInterfaceStyle != .dark {
                window.overrideUserInterfaceStyle = .dark
            }

        default:
            if window.overrideUserInterfaceStyle != .unspecified {
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
    
    @objc public class func update(searchBar: UISearchBar) {
        updateKeyboardAppearance(for: searchBar)
        
        switch theme {
        case .light:
            searchBar.barStyle = .default
            UITextField.appearance().keyboardAppearance = .default
        case .dark:
            searchBar.barStyle = .black
            UITextField.appearance().keyboardAppearance = .dark
        }
        searchBar.isTranslucent = true
        if #available(iOS 26.0, *) {
            UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
                .setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        }
        else {
            UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
                .setTitleTextAttributes([.foregroundColor: UIColor.primary], for: .normal)
        }
        searchBar.searchTextField.textColor = .label
    }
    
    @objc public class func update(switchAppearance: UISwitch) {
        switchAppearance.onTintColor = .primary
    }
}
