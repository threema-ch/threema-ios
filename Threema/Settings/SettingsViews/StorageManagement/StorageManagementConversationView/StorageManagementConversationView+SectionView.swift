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
import ThreemaMacros

extension StorageManagementConversationView {
    
    // MARK: - SectionView
    
    struct SectionView: View {
        
        @Binding var amount: Int
        let section: Section
        let action: () -> Void

        var body: some View {
            StorageView(bodyText: section.localizedDescription) {
                ConversationManageButton(action: action)
                    .disabled(amount == 0)
            } header: {
                LabelHeader(
                    symbol: section.symbol,
                    title: section.localizedTitle,
                    secondary: "\(amount)"
                )
            }
        }
    }
    
    // MARK: - SectionView Components
    
    struct StorageView<Content: View, Header: View>: View {
        var bodyText: String
        var content: () -> Content
        var header: () -> Header
        
        var body: some View {
            GroupBox(
                label: header(),
                content: {
                    Text(bodyText)
                        .padding(.top, 1)
                        .padding(.bottom, 8)
                        .font(.footnote)
                    Spacer()
                    content()
                }
            )
            .groupBoxStyle(.storageManagement)
        }
    }
    
    struct ConversationManageButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(#localize("manage"))
                    .font(.headline)
                    .padding(4)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    struct LabelHeader: View {
        let symbol: String
        let title: String
        let secondary: String
        
        var body: some View {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text(secondary)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
