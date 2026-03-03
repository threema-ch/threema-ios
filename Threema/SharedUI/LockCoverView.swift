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

import SwiftUI
import ThreemaFramework

struct LockCoverView: View {
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            Image(uiImage: .lockCover)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 290, maxHeight: 20)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}

@objc public class LockCoverViewProvider: NSObject {
    @objc static let lockCoverViewController: UIViewController = UIHostingController(rootView: LockCoverView())
}

#Preview {
    LockCoverView()
}
