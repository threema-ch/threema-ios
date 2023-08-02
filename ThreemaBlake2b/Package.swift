// swift-tools-version: 5.7

//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) Threema GmbH
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

import PackageDescription

let package = Package(
    name: "ThreemaBlake2b",
    products: [
        .library(
            name: "ThreemaBlake2b",
            targets: ["ThreemaBlake2b"]
        ),
    ],
    targets: [
        .target(
            name: "CBlake2"
            // Reference implementation from https://github.com/BLAKE2/BLAKE2/tree/master/ref
            // as of 17.05.2023
        ),
        .target(
            name: "CThreemaBlake2b",
            dependencies: ["CBlake2"]
        ),
        .target(
            name: "ThreemaBlake2b",
            dependencies: ["CBlake2", "CThreemaBlake2b"]
        ),
        .testTarget(
            name: "ThreemaBlake2bTests",
            dependencies: ["ThreemaBlake2b"]
        ),
    ]
)
