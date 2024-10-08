//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

struct ProfilePictureDebugView: View {
    
    var body: some View {
        ScrollView {
            HStack(spacing: 0) {
                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "DD"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.systemBackground.color)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)

                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "0D"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.groupTableViewBackground.color)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
                
                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "SP"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.systemBackground.color)
                .environment(\.colorScheme, .dark)
                .preferredColorScheme(.dark)
                
                VStack {
                    ForEach(UIColor.IDColor.debugColors, id: \.self) { color in
                        Image(uiImage: ProfilePictureGenerator.generateImage(
                            for: .contact(letters: "VW"),
                            color: color
                        ))
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                    }
                }
                .padding()
                .background(UIColor.groupTableViewBackground.color)
                .environment(\.colorScheme, .dark)
                .preferredColorScheme(.dark)
            }
        }
        .navigationTitle(Text(verbatim: "New Profile Picture"))
    }
}

#Preview {
    ProfilePictureDebugView()
}
