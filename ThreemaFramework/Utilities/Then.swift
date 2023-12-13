//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

///
/// `Then` allows you to modify properties using a closure. It makes code more readable and requires less code to write.
///
/// Normally we would need to create variables even for the simplest of tasks. Consider the following:
///
/// ```swift
///     func wrappedModalNavigationView(delegate: UINavigationControllerDelegate) -> some View {
///         WrapperView {
///             let nav = ModalNavigationController(rootViewController: self)
///             nav.delegate = delegate
///             return nav
///         }
///     }
/// ```
///
/// Now, using `Then` we can make that boilerplate go away just by using `.then { }`
/// ```swift
///     func wrappedModalNavigationView(delegate: UINavigationControllerDelegate) -> some View {
///         ModalNavigationController(rootViewController: self).then {
///             $0.delegate = delegate
///         }
///     }
/// ```
///
/// - Note: Usage of `Then` should be limited to `UIKit` code in most cases.
public protocol Then { }

extension Then where Self: AnyObject {
    /// Modify properties using a closure
    ///
    /// ## Example
    ///
    /// ```swift
    ///     let view = UIView().then {
    ///         $0.back = 100
    ///         $0.height = 100
    ///     }
    /// ```
    @inlinable
    public func then(_ block: (Self) throws -> Void) rethrows -> Self {
        try block(self)
        return self
    }
}

extension Then where Self: Any {
    
    /// Modify and copy using a closure, should be used for value types
    ///
    /// ## Example
    ///
    /// ```swift
    ///     let size = CGSize().then {
    ///         $0.width = 100
    ///         $0.height = 100
    ///     }
    /// ```
    @inlinable
    public func then(_ block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }
}

// MARK: - NSObject + Then

extension NSObject: Then { }

// MARK: - Array + Then

extension Array: Then { }

// MARK: - Set + Then

extension Set: Then { }

// MARK: - Dictionary + Then

extension Dictionary: Then { }

// MARK: - CGPoint + Then

extension CGPoint: Then { }

// MARK: - CGRect + Then

extension CGRect: Then { }

// MARK: - CGSize + Then

extension CGSize: Then { }

// MARK: - CGVector + Then

extension CGVector: Then { }
