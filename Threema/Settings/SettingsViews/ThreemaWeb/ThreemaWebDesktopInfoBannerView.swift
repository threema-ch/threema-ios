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
import ThreemaMacros

struct ThreemaWebDesktopInfoBannerView: View {
    let onTap: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.primary)
                    Text(String.localizedStringWithFormat(
                        #localize("settings_threema_web_desktop_banner_title"),
                        TargetManager.localizedAppName
                    ))
                    .bold()
                    Spacer()
                }
                
                Text(#localize("settings_threema_web_desktop_banner_message"))
            }
            
            Button {
                dismissAction()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(Colors.textProminentButton.color)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor)
        .cornerRadius(10)
        .padding()
        .background(Colors.backgroundView.color)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ThreemaWebDesktopInfoBannerView(onTap: { }, dismissAction: { })
}
