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
import ThreemaMacros

public struct ScreenshotPreventionView: View {
    
    public init() { }
    
    public var body: some View {
        ZStack {
            Colors.textInverted.color
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Image(uiImage: Colors.threemaLogo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 150)
                    .padding()
                
                Spacer()
                
                Image(systemName: "eye.slash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .padding()
                
                Text(#localize("screenshot_prevention_info"))
                    .font(.title3)
                    .fontWeight(.medium)
                
                Spacer()
                Spacer()
            }
            .padding([.top, .bottom])
            .padding([.leading, .trailing], 50)
            .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ScreenshotPreventionView()
}
