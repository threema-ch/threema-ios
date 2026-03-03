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

import Foundation

// Based on https://github.com/apple/swift-crypto/blob/d1c6b70f7c5f19fb0b8750cb8dcdf2ea6e2d8c34/Sources/Crypto/Util/Zeroization.swift
extension Data {
    mutating func zeroize() {
        _ = withUnsafeMutableBytes {
            memset_s($0.baseAddress!, $0.count, 0, $0.count)
        }
    }
}
