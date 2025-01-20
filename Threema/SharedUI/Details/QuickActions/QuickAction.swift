//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

protocol QuickActionUpdate {
    func reload()
    func hide()
}

/// Description of a quick action
///
/// Use it to define quick actions in a `QuickActionsView`.
struct QuickAction {
    typealias ImageNameProvider = () -> String
    
    /// String of image available as asset
    let imageNameProvider: ImageNameProvider
    
    /// Title of action
    let title: String
    
    let accessibilityIdentifier: String
    
    /// Action performed when selected
    let action: (QuickActionUpdate) -> Void
    
    /// Create a quick action
    /// - Parameters:
    ///   - imageNameProvider: Provider for name of current SF Symbol to show
    ///   - title: Quick action title
    ///   - action: Action called when quick action is invoked
    ///   - accessibilityIdentifier: Identifier to find the button in UI tests
    init(
        imageNameProvider: @escaping ImageNameProvider,
        title: String,
        accessibilityIdentifier: String,
        action: @escaping (QuickActionUpdate) -> Void
    ) {
        self.imageNameProvider = imageNameProvider
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }
    
    /// Create a quick action with a fixed image
    /// - Parameters:
    ///   - imageName: Name of SF Symbol to show
    ///   - title: Quick action title
    ///   - action: Action called when quick action is invoked
    ///   - accessibilityIdentifier: Identifier to find the button in UI tests
    init(
        imageName: String,
        title: String,
        accessibilityIdentifier: String,
        action: @escaping (QuickActionUpdate) -> Void
    ) {
        self.init(
            imageNameProvider: { imageName },
            title: title,
            accessibilityIdentifier: accessibilityIdentifier,
            action: action
        )
    }
}

// MARK: - Hashable

extension QuickAction: Hashable {
    static func == (lhs: QuickAction, rhs: QuickAction) -> Bool {
        lhs.title == rhs.title
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
}
