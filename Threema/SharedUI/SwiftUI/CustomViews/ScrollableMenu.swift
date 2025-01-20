//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

typealias ScrollableMenuView = UIHostingController<ScrollableMenu<ContactListFilterItem>>

extension ScrollableMenuView {
    convenience init(_ didSelect: @escaping (ContactListFilterItem) -> Void) {
        self.init(rootView: ScrollableMenu(didSelect: didSelect))
        view.backgroundColor = .clear
    }
}

struct PlainIndex: IndexViewStyle {
    func _makeBody(configuration: _Configuration) -> EmptyView {
        EmptyView()
    }
    
    typealias _Body = EmptyView
}

struct ScrollableMenu<Item: MenuItem>: View {
    var didSelect: (Item) -> Void
    
    @State var selected = Item.allCases.first! {
        didSet { didSelect(selected) }
    }
    
    var body: some View {
        menuView
            .horizontalFadeOut(fadeLength: 75)
    }
    
    private var tabView: some View {
        VStack {
            TabView(selection: $selected) {
                ForEach(Array(Item.allCases)) { item in
                    if item.enabled {
                        HStack {
                            menu(item)
                        }.tag(item)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PlainIndex())
        }
    }
    
    private var menuView: some View {
        ZStack {
            HStack { }
                .frame(minWidth: 300)
            HStack {
                Text(selected.label)
                    .bold()
                    .hidden()
                    .padding(.horizontal)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.down")
                    .foregroundColor(.accentColor)
                    .animation(.spring, value: selected)
            }
            .frame(maxWidth: .infinity)
            tabView
        }
    }
    
    private func menu(_ item: Item) -> some View {
        Menu {
            ForEach(Array(Item.allCases)) { item in
                if item.enabled {
                    Button(action: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                            selected = item
                        }
                    }) {
                        HStack {
                            item.icon.image
                            Text("\(item.label)")
                        }
                        .applyIf(item.accessibilityLabel != nil) { view in
                            view.accessibilityLabel(item.accessibilityLabel!)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(item.label)
                    .bold()
                    .tint(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.bouncy.speed(2), value: selected)
        .onChange(of: selected) {
            didSelect($0)
        }
    }
}
