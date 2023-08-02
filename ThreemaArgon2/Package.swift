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
    name: "ThreemaArgon2",
    products: [
        .library(
            name: "ThreemaArgon2",
            targets: ["ThreemaArgon2"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/P-H-C/phc-winner-argon2",
            revision: "f57e61e"
        ),
    ],
    targets: [
        .target(
            name: "ThreemaArgon2",
            dependencies: [
                // This product cannot be renamed, because it isn't Swift only code:
                // https://github.com/apple/swift-package-manager/blob/main/Documentation/ModuleAliasing.md
                .product(name: "argon2", package: "phc-winner-argon2"),
            ]
        ),
        .testTarget(
            name: "ThreemaArgon2Tests",
            dependencies: ["ThreemaArgon2"]
        ),
    ]
)
