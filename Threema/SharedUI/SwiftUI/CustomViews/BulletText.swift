//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import SwiftUI

struct BulletText: View {
    let string: String
    let showIcon: Bool
    
    init(string: String, showIcon: Bool = false) {
        self.string = string
        self.showIcon = showIcon
    }
    
    var body: some View {
        Label {
            Text(verbatim: "· \(string)")
        } icon: {
            if showIcon {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(UIColor.primary.color)
            }
        }
        .labelStyle(TrailingLabelStyle())
    }
}

struct BulletText_Previews: PreviewProvider {
    static var previews: some View {
        BulletText(string: "Text")
    }
}
