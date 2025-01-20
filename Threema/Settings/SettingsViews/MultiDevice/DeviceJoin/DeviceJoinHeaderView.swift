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

struct DeviceJoinHeaderView: View {
    
    let title: String
    let description: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .bold()
                .padding(.bottom)
                .accessibilityAddTraits(.isHeader)
            
            Text(.init(description))
                .padding(.bottom)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct DeviceJoinHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceJoinHeaderView(title: "Hello World", description: "Tap this thing below to execute some action.")
    }
}
