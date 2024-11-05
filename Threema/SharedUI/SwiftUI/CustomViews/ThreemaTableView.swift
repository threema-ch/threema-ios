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

import Combine
import SwiftUI
import ThreemaFramework
@_spi(Advanced) import SwiftUIIntrospect

struct ThreemaTableView<Content: View>: View {
    
    var content: () -> Content
    
    @State private var lastContentOffset: CGPoint = .zero
    @State private var cancellable: Set<AnyCancellable> = []
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        List {
            content()
        }
        .introspect(.list, on: .iOS(.v13, .v14, .v15), customize: offsetHandler)
        .introspect(.list, on: .iOS(.v16), customize: offsetHandler)
        .introspect(.list, on: .iOS(.v17...), customize: offsetHandler)
    }
    
    private func offsetHandler(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            scrollView
                .publisher(for: \.contentOffset)
                .receive(on: RunLoop.main)
                .removeDuplicates()
                .sink { offset in
                    if offset != lastContentOffset {
                        lastContentOffset = offset
                    }
                }
                .store(in: &cancellable)
        }
    }
}

#Preview {
    ThreemaTableView {
        Section {
            Text(verbatim: "A 1")
            Text(verbatim: "B 1")
        }
        Section {
            Text(verbatim: "A 2")
            Text(verbatim: "B 2")
        }
    }
}
