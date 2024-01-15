//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

struct SettingsListView: View {
    let cellTitle: String
    let imageSystemName: String
    let width: CGFloat = 28
    
    var body: some View {
        Label {
            Text(cellTitle)
        } icon: {
            Image(systemName: imageSystemName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
                .padding(5)
                .frame(width: width, height: width, alignment: .center)
                .background(.gray)
                .cornerRadius(5)
        }
    }
}

struct SettingsListView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsListView(cellTitle: "Preview Text", imageSystemName: "trash.fill")
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
