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

import Foundation

public struct IntermediateItem {
    public var itemProvider: NSItemProvider
    public var type: String
    public var secondType: String?
    public var caption: String?
}

// MARK: - Equatable

extension IntermediateItem: Equatable {
    public static func == (lhs: IntermediateItem, rhs: IntermediateItem) -> Bool {
        lhs.itemProvider == rhs.itemProvider &&
            lhs.type == rhs.type &&
            lhs.secondType == rhs.secondType &&
            lhs.caption == rhs.caption
    }
}

// MARK: - Comparable

extension IntermediateItem: Comparable {
    public static func < (lhs: IntermediateItem, rhs: IntermediateItem) -> Bool {
        lhs.itemProvider.description < rhs.itemProvider.description &&
            lhs.type < rhs.type &&
            lhs.secondType ?? "" < rhs.secondType ?? "" &&
            lhs.caption ?? "" < rhs.caption ?? ""
    }
}

// MARK: - Hashable

extension IntermediateItem: Hashable { }
