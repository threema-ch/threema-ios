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

struct EnterLicenseInfoView: View {
    var dismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 50.0) {
                    VStack {
                        VStack {
                            Image(uiImage: Colors.threemaLogo)
                                .resizable()
                                .scaledToFit()
                                .aspectRatio(contentMode: .fit)
                                .padding(.horizontal, 60.0)
                                .padding(.top, 20.0)
                            
                            Text(
                                #localize("enter_license_infoview_subtitle")
                            )
                            .padding(.horizontal, 10.0)
                            .padding(.bottom, 10.0)
                            .multilineTextAlignment(.center)
                            .font(.title2)
                        }
                        .accessibilityElement(children: .combine)
                        
                        if !TargetManager.isOnPrem {
                            Text(.init(String.localizedStringWithFormat(
                                #localize("enter_license_infoview_more_link"),
                                TargetManager.localizedAppName
                            )))
                            .underline()
                            .environment(\.openURL, OpenURLAction(handler: handleWorkURL))
                        }
                    }
                                        
                    GroupBox {
                        VStack {
                            Image(uiImage: Colors.consumerAppIcon)
                                .resizable()
                                .frame(width: 50, height: 50, alignment: .center)
                                .scaledToFit()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                                
                            Image(uiImage: Colors.darkConsumerLogo)
                                .resizable()
                                .scaledToFit()
                                .aspectRatio(contentMode: .fit)
                                .padding(.horizontal, 80)
                                
                            Text(#localize("enter_license_infoview_private_use"))
                                .font(.title3)
                        }
                            
                        // Note that this always refers to "Threema" and thus isn't parametrized
                        Text(#localize("enter_license_infoview_threema_description"))
                            .font(.body)
                                                        
                        Button {
                            if let url = URL(string: "itms-apps://itunes.apple.com/app/id578665578") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            // Note that this always refers to "Threema" and thus isn't parametrized
                            Text(#localize("enter_license_infoview_appstore_link"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(UIColor(resource: .accentColorPrivateShared).color)
                    }
                    .groupBoxStyle(.wizard)
                    .environment(\.colorScheme, .light)
                    .accessibilityElement(children: .combine)
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
            }
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text(#localize("enter_license_infoview_login"))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
        
    private func handleWorkURL(_ url: URL) -> OpenURLAction.Result {
        UIApplication.shared.open(ThreemaURLProvider.enterLicenseWorkInfo)
        return .handled
    }
}

#Preview {
    EnterLicenseInfoView(dismiss: { })
}
