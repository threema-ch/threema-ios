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
                                "enter_license_infoview_subtitle".localized
                            )
                            .padding(.horizontal, 10.0)
                            .padding(.bottom, 10.0)
                            .multilineTextAlignment(.center)
                            .font(.title2)
                        }
                        .accessibilityElement(children: .combine)

                        Text(.init("enter_license_infoview_more_link".localized))
                            .underline()
                            .environment(\.openURL, OpenURLAction(handler: handleWorkURL))
                    }
                                        
                    GroupBox(
                        content: {
                            VStack {
                                Image(uiImage: Colors.consumerLogoRoundCorners)
                                    .resizable()
                                    .frame(width: 50, height: 50, alignment: .center)
                                    .scaledToFit()
                                    .aspectRatio(contentMode: .fit)
                                
                                Image(uiImage: Colors.darkConsumerLogo)
                                    .resizable()
                                    .scaledToFit()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(.horizontal, 80)
                                
                                Text("enter_license_infoview_private_use".localized)
                                    .font(.title2)
                            }
                            
                            Text("enter_license_infoview_threema_description".localized)
                                .font(.body)
                                                        
                            Button {
                                if let url = URL(string: "itms-apps://itunes.apple.com/app/id578665578") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("enter_license_infoview_appstore_link".localized)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accentColor(Colors.green.color)
                        }
                    )
                    .groupBoxStyle(.wizard)
                    .environment(\.colorScheme, .light)
                    .accessibilityElement(children: .combine)
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
            }
            .background(
                Image("WizardBg")
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
                    .edgesIgnoringSafeArea(.all)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("enter_license_infoview_login".localized)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
        
    private func handleWorkURL(_ url: URL) -> OpenURLAction.Result {
        if let url = URL(string: "https://threema.ch/work?li=in-app-work") {
            UIApplication.shared.open(url)
            return .handled
        }
        return .discarded
    }
}

#Preview {
    EnterLicenseInfoView(dismiss: { })
}
