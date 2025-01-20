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
import ThreemaFramework

protocol SettingsListItemProtocol: View { }

struct SettingsListItemView: View, SettingsListItemProtocol {
    let cellTitle: String
    let accessoryText: String?
    let resource: ThreemaImageResource?
    let width: CGFloat = 28
        
    init(cellTitle: String, accessoryText: String? = nil, image resource: ThreemaImageResource? = nil) {
        self.cellTitle = cellTitle
        self.accessoryText = accessoryText
        self.resource = resource
    }
    
    var body: some View {
        HStack {
            Label {
                Text(cellTitle)
            } icon: {
                if let resource {
                    Image(resource)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .padding(5)
                        .frame(width: width, height: width, alignment: .center)
                        .background(.gray)
                        .cornerRadius(5)
                }
            }
            Spacer()
            if let accessoryText {
                Text(accessoryText)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsListImageItemView: View, SettingsListItemProtocol {
    let cellTitle: String
    let subCellTitle: String?
    let image: Image
    let width: CGFloat = 28

    var body: some View {
        Label {
            if let subCellTitle {
                VStack {
                    Text(cellTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                    Text(subCellTitle)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                }
                .padding(.leading, 1)
            }
            else {
                Text(cellTitle)
                    .padding(.leading, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } icon: {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: width, alignment: .center)
                .background(.gray)
                .cornerRadius(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .labelStyle(CustomImageLabelStyle())
    }
}

struct CustomImageLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
                .padding([.bottom, .trailing, .top], 5.0)
            configuration.title
        }
    }
}

struct SettingsListItemView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsListItemView(cellTitle: "Preview Text", accessoryText: nil, image: .systemImage("trash.fill"))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
