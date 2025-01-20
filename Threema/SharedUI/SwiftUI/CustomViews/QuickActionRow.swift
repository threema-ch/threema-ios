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

struct QuickActionRow: View {
    private var actions: [Action] = []
    
    init(@ArrayBuilder<Action> actions: () -> [Action]) {
        self.actions = actions()
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 8.0) {
                ForEach(actions, id: \.id) { action in
                    QuickActionButton(model: action)
                }
            }.frame(height: 66)
        }.frame(maxWidth: .infinity)
    }
    
    struct Action: Identifiable {
        let id = UUID()
        let action: () -> Void
        let icon: String
        let title: String
        let buttonAccessibilityIdentifier: String
        let accessibilityIdentifier: String
    }
    
    struct QuickActionButton: View {
        let model: Action
        
        var body: some View {
            Button(action: model.action) {
                // Padding values here are fine-tuned to the current usage, could changed in future
                VStack(spacing: 0.0) {
                    Image(systemName: model.icon)
                        .font(.system(size: 24))
                        .padding(.top, 6)
                        .frame(maxHeight: .infinity)
                    Text(model.title)
                        .padding(.bottom, 8)
                        .font(.footnote)
                }
                // Needed to make full button tappable
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(model.accessibilityIdentifier)
            }
            .accessibilityIdentifier(model.buttonAccessibilityIdentifier)
            .buttonStyle(QuickActionButtonStyle())
        }
    }
}

private struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Based on configuration of the UIKit version of `QuickActionButton`
        configuration.label
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundStyle(.tint)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.3 : 1)
        // No shadow as it gets cut off in the current usage in Profile
    }
}

#Preview {
    func actions() -> [QuickActionRow.Action] {
        [
            .init(
                action: {
                    print("share QRCode")
                },
                icon: "qrcode",
                title: "qrcode",
                buttonAccessibilityIdentifier: "qrcode-button",
                accessibilityIdentifier: "qrcode"
            ),
            .init(
                action: {
                    print("share id")
                },
                icon: "square.and.arrow.up.fill",
                title: "Share ID",
                buttonAccessibilityIdentifier: "shareID-button",
                accessibilityIdentifier: "shareID"
            ),
        ]
    }
    
    return QuickActionRow(actions: actions)
        .padding()
        .background(Color.blue)
}
