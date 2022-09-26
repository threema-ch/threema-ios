//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

/// Base class for `UIButton`s that are implemented in code
///
/// It provides a color method to update your colors on theme changes (`updateColors()`)
/// and a default action that gets called when the button is tapped (`Action`).
///
/// If you don't need more information during initialization you can just override `configureButton()`.
open class ThemedCodeButton: UIButton {
    public typealias Action = (ThemedCodeButton) -> Void
    
    private let action: Action
    
    // MARK: - Lifecycle
    
    public init(frame: CGRect = .zero, action: @escaping Action) {
        self.action = action
        
        super.init(frame: frame)
        
        configureButton()
        registerObserver()
    }
    
    @available(*, unavailable)
    override init(frame: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Called during initialization
    open func configureButton() {
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    private func registerObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorThemeChanged),
            name: NSNotification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
    }
    
    // MARK: - Update
    
    /// Called whenever the colors of the button should be set to the current theme colors
    open func updateColors() { }
    
    // MARK: - Action
    
    @objc private func buttonTapped() {
        action(self)
    }
    
    // MARK: - Notification
    
    @objc private func colorThemeChanged() {
        updateColors()
    }
}
