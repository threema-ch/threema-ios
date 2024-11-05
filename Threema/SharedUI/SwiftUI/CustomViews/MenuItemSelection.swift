//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

struct MenuItemSelection<Item: MenuItem>: View {
    @State var selected = Item.allCases.first! {
        didSet { didSelect(selected) }
    }
    
    var didSelect: (Item) -> Void
    
    var body: some View {
        Menu {
            ForEach(Array(Item.allCases)) { item in
                Button(action: {
                    selected = item
                }) {
                    HStack {
                        item.icon.image
                        Text("\(item.label)")
                    }
                }.applyIf(!item.enabled) {
                    $0.hidden()
                }
            }
        } label: {
            HStack {
                Text(selected.label).bold()
                    .tint(.primary)
                Image(systemName: "chevron.down")
                    .buttonStyle(PlainButtonStyle())
            }
            .animation(.spring, value: selected)
            .frame(width: 200, height: 44)
        }
    }
}
