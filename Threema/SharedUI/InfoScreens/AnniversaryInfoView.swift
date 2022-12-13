//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

struct AnniversaryInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    let icon: AppIcon = .default
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            
            Image(uiImage: icon.preview)
                .resizable()
                .frame(width: 250, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 55, style: .continuous))
                .padding(.vertical)
            
            Text(BundleUtil.localizedString(forKey: "anniversary_view_title"))
                .font(.title)
                .bold()
                .padding(.bottom)
            
            Text(BundleUtil.localizedString(forKey: "anniversary_view_text"))
                .font(.title3)
                .padding(.bottom)
            
            Text(BundleUtil.localizedString(forKey: "anniversary_view_icon_info"))
                .font(.subheadline)
                .foregroundColor(Color(uiColor: Colors.textLight))
        }
        .padding(.horizontal)
        .multilineTextAlignment(.center)
        
        Spacer()
        Button {
            dismiss()
        } label: {
            Text(BundleUtil.localizedString(forKey: "continue"))
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .padding()
        
        .onDisappear {
            let defaults = AppGroup.userDefaults()
            defaults?.set(true, forKey: Constants.showed10YearsAnniversaryView)
            defaults?.synchronize()
        }
    }
}

struct AnniversaryInfoView_Previews: PreviewProvider {
    static var previews: some View {
        AnniversaryInfoView()
    }
}
