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
import ThreemaMacros

struct WorkReferralCellView: View {
    
    let imageWidth: CGFloat = 100
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text(#localize("work_referral_cell_title"))
                    .font(.title3.bold())
                
                HStack {
                    Text(#localize("work_referral_cell_message"))
                    Spacer(minLength: imageWidth * 0.6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            
            Image(systemName: "gift")
                .resizable()
                .frame(width: imageWidth, height: imageWidth)
                .foregroundStyle(UIColor(red: 0, green: 0.329, blue: 0.627, alpha: 1).color)
                .offset(x: 48, y: 7)
        }
    }
}

#Preview {
    NavigationView {
        List {
            Section {
                NavigationLink {
                    EmptyView()
                } label: {
                    WorkReferralCellView()
                }
                .listRowBackground(
                    UIColor.primaryColorWork
                        .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).color
                )
            }
        }
    }
}
