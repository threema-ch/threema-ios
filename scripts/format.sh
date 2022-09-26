#!/usr/bin/env bash
#  _____ _
# |_   _| |_  _ _ ___ ___ _ __  __ _
#   | | | ' \| '_/ -_) -_) '  \/ _` |_
#   |_| |_||_|_| \___\___|_|_|_\__,_(_)
#
# Threema iOS Client
# Copyright (c) 2021 Threema GmbH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License, version 3,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Format the project with SwiftFormat
#
# Use this script like `swiftformat` directly. It assumes you have a swift format package in
# `/scripts/format` relative to the project path you provide.
#
# To update to the most recent version of SwiftFormat go to `scripts/format` and run
#     swift package update

set -euo pipefail

package_path="$1/scripts/format"

# https://github.com/nicklockwood/SwiftFormat#2-add-a-build-phases-to-your-app-target
SDKROOT=(xcrun --sdk macosx --show-sdk-path)
swift run -c release --package-path "$package_path" swiftformat "$@"
