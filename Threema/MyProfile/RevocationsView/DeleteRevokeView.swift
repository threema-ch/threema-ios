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

struct DeleteRevokeView: View {
    @Environment(\.dismiss) var dismiss
    
    var alreadyDeleted = false
    
    @State private var successViewType: SuccessViewType = .delete
    @State private var tabSelection = 0
    
    var body: some View {
        TabView(selection: $tabSelection) {
            if !alreadyDeleted {
                DeleteRevokeOverviewView(tabSelection: $tabSelection)
                    .tag(0)
                RevokeView(tabSelection: $tabSelection, successViewType: $successViewType)
                    .tag(1)
            }
            DeleteRevokeSuccessView(successViewType: $successViewType)
                .tag(2)
        }
        .padding()
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .animation(.easeOut(duration: 2.0), value: tabSelection)
        .background(
            Image("WizardBg")
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
                .edgesIgnoringSafeArea(.all)
        )
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            UIScrollView.appearance().isScrollEnabled = false
        }
        .onDisappear {
            UIScrollView.appearance().isScrollEnabled = true
        }
        .navigationBarHidden(true)
        .dynamicTypeSize(.small ... .xxxLarge)
        .colorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }
}

enum SuccessViewType {
    case delete, revoke
}

#Preview {
    DeleteRevokeView()
}
