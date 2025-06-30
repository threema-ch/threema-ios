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

struct DeviceJoinSuccessView: View {
    
    @Binding var showWizard: Bool

    var body: some View {
        VStack {
            GeometryReader { geometryProxy in
                ScrollView {
                    VStack {
                        Spacer()

                        Image("PartyPopper")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(50)
                            .accessibilityHidden(true)
                        
                        DeviceJoinHeaderView(
                            title: #localize("multi_device_join_linked_successfully_title"),
                            description: String.localizedStringWithFormat(
                                #localize("multi_device_join_linked_successfully_info"),
                                TargetManager.appName
                            )
                        )
                        
                        Spacer()
                        Spacer()
                    }
                    .padding(24)
                    .frame(minHeight: geometryProxy.size.height)
                }
            }
            
            Spacer()
            
            // So far there is not exact button that matches the one used by system apps
            Button {
                showWizard = false
            } label: {
                Text(#localize("continue"))
                    .font(.title3) // This is a little bit too big
                    .bold()
                    .foregroundStyle(Colors.textProminentButton.color)
                    .padding(8)
                    .frame(maxWidth: .infinity)
            }
            .padding([.horizontal, .bottom], 24)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .navigationBarBackButtonHidden()
    }
}

struct DeviceJoinSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeviceJoinSuccessView(showWizard: .constant(true))
        }
    }
}
