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

import UIKit

/// Collection of our custom UI components
///
/// Add a new component:
/// 1. Add, if possible, a property with the view in the correct "Components" subsection
/// 2. Add a short description
/// 3. Add property to "Stack" in the same order as it appears in the "Components" section
final class UIComponentsViewController: ThemedViewController {

    // MARK: - Components
    
    // MARK: Buttons
    
    /// Simple button showing the SF Symbol vibrant in a circle with a blurry background
    private lazy var blurCircleButton = BlurCircleButton(
        sfSymbolName: "play.fill",
        accessibilityLabel: "Play"
    ) { button in
        print("BlurCircleButton tapped.")
        
        if let blurCircleButton = button as? BlurCircleButton {
            let newSymbolName = [
                "stop.fill",
                "play.fill",
                "pause.fill",
                "shuffle",
                "repeat",
            ].randomElement() ?? "play.fill"
            
            print("Switch symbol to '\(newSymbolName)'")
            
            blurCircleButton.updateSymbol(to: newSymbolName)
        }
    }
    
    /// Simple button showing the SF Symbol in a circle with a light green background
    private lazy var circleButton = CircleButton(sfSymbolName: "camera", accessibilityLabel: "Take photo") { button in
        print("CircleButton tapped: \(button.titleLabel?.text ?? "")")
    }
    
    /// Delete button with opaque background
    ///
    /// Before using this see if `UIButton(type: .close)` provided by the system fits you. This should only be used if
    /// you really need an opaque delete button.
    private lazy var opaqueDeleteButton = OpaqueDeleteButton { button in
        print("OpaqueDeleteButton tapped: \(button.titleLabel?.text ?? "")")
    }
    
    /// Highly specialized quick action button used in contact and group details
    ///
    /// This is not made for a white background, but a light gray one.
    private lazy var quickActionButton = QuickActionButton(
        imageNameProvider: { "bell.fill" },
        title: "Do Not Distrub",
        accessibilityIdentifier: "ThemedViewControllerDndQuickActionButton",
        action: { quickActionUpdate in
            print("QuickActionButton tapped")
            quickActionUpdate.reload()
        },
        shadow: true
    )
    
    // MARK: - Setup wizard components
    
    /// Imitate setup wizard screen: Background color of parent view for SetupButton and SetupTextField has to be dark
    /// gray
    private lazy var setupContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .darkGray
        view.addSubview(setupButton)
        view.addSubview(setupTextField)
        return view
    }()
    
    /// Setup button for setup wizard screens
    private lazy var setupButton: SetupButton = {
        let button = SetupButton(frame: CGRect(x: 10, y: 10, width: 300, height: 40))
        button.setTitle("Setup wizard button", for: .normal)
        return button
    }()
    
    /// Setup text field for setup wizard screens, height must be 40
    private lazy var setupTextField: SetupTextField = {
        let textField = SetupTextField(frame: CGRect(x: 10, y: 60, width: 300, height: 40))
        textField.delegate = self
        textField.placeholder = "Password"
        textField.showIcon = UIImage(systemName: "key.fill")
        return textField
    }()
    
    // MARK: Cells
    
    /// - `GroupCell`: Show groups in a list
    
    // MARK: - Stack
    
    private lazy var allComponentsStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            blurCircleButton,
            circleButton,
            opaqueDeleteButton,
            quickActionButton,
            setupContainer,
        ])
        
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        
        let margin: CGFloat = 24
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: margin,
            leading: margin,
            bottom: margin,
            trailing: margin
        )
        stackView.isLayoutMarginsRelativeArrangement = true
        
        return stackView
    }()

    // MARK: - Implementation details
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "UI Components"
        
        let scrollView = UIScrollView()
        
        scrollView.addSubview(allComponentsStack)
        view.addSubview(scrollView)
        
        allComponentsStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            allComponentsStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            allComponentsStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            allComponentsStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            allComponentsStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            setupContainer.heightAnchor.constraint(equalToConstant: 110),
            setupContainer.widthAnchor.constraint(equalToConstant: 320),
        ])
    }
}

// MARK: - SetupTextFieldDelegate

extension UIComponentsViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        print(sender.text ?? "")
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        print(sender.isFocused)
    }
}
