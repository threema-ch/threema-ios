//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

/// A class designed to manage and restore view controller stacks across multiple indices.
///
/// The name "ThetaStack" draws inspiration from neuroscience, where theta waves in the brain are associated with memory
/// encoding and spatial navigation. Similar to how theta waves facilitate spatial navigation and memory formation in
/// the brain, this class encodes and retrieves navigation states (stacks of view controllers) for different contexts or
/// indices.
public final class ThetaStack {

    private(set) var stacks: [ThreemaTabBarController.TabBarItem: [UIViewController]]
    
    public init() {
        self.stacks = [:]
    }

    /// Stores a stack of view controllers for a specific index.
    ///
    /// - Parameters:
    ///   - stack: An array of `UIViewController` objects to store.
    ///   - index: The integer key used to identify and retrieve this stack later.
    public func store(stack: [UIViewController], for index: ThreemaTabBarController.TabBarItem) {
        stacks[index] = stack
    }

    /// Restores the stack of view controllers associated with a given index.
    ///
    /// - Parameter index: The integer key identifying which stack to restore.
    /// - Returns: An array of `UIViewController` objects stored at the specified index, or an empty array if none
    /// exists for that index.
    public func restore(for index: ThreemaTabBarController.TabBarItem) -> [UIViewController] {
        stacks[index] ?? []
    }
}
