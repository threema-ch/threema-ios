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

import CocoaLumberjackSwift
import SwiftUI
import ThreemaFramework

struct AppIconSettingsView: View {
    @State var currentlySelected = UIApplication.shared.alternateIconName
    
    var body: some View {
        List {
            ForEach(AppIcon.allCases, id: \.self) { icon in
                HStack {
                    Image(uiImage: icon.preview)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 75, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .padding(.trailing)
                    
                    VStack(alignment: .leading) {
                        Text(icon.displayTitle)
                        Text(icon.displayInfo)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()

                    if icon.iconName == currentlySelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(uiColor: Colors.primary))
                            .imageScale(.large)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    setIcon(icon: icon)
                }
            }
            .navigationTitle("App Icons")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func isSelectedIcon(icon: AppIcon) -> Bool {
        let selected = UIApplication.shared.alternateIconName
        return icon.iconName == selected
    }
    
    private func setIcon(icon: AppIcon) {
        UIApplication.shared.setAlternateIconName(icon.iconName) { error in
            if let error = error {
                DDLogError(
                    "Error setting alternate icon: \(icon.iconName ?? "default"). Desc: \(error.localizedDescription)"
                )
            }
            currentlySelected = icon.iconName
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconSettingsView()
    }
}
