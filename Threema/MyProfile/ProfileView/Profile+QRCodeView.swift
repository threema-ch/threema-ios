//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

extension ProfileView {
    struct QRCodeView: View {
        static let animationDuration = 0.3
        
        @EnvironmentObject var model: ProfileViewModel
        @AccessibilityFocusState(for: .voiceOver) private var isCloseFocused: Bool
        
        let dismiss: () -> Void
        @State private var scale: CGFloat = 0
        
        var body: some View {
            ZStack {
                VStack {
                    VStack {
                        Spacer()
                        Image(uiImage: model.qrCodeImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .accessibilityIgnoresInvertColors(true)
                            .padding(20)
                            .accessibilityLabel("profile_big_qr_code".localized)
                            .background {
                                Color.white
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .circular))
                        Spacer()
                    }
                    .scaleEffect(CGSize(width: scale, height: scale))
                    .padding()
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + QRCodeView.animationDuration) {
                        isCloseFocused = true
                    }
                    
                    withAnimation(.spring.speed(2)) {
                        scale = 1
                    }
                }
                .accessibilityLabel("profile_big_qr_code_cover_view".localized)
                .ignoresSafeArea()
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDismiss, label: {
                            Image(systemName: "xmark").imageScale(.large)
                        })
                        .padding()
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .accessibilityLabel("close".localized)
                    .accessibilityFocused($isCloseFocused)
                    Spacer()
                }.padding()
            }
            .background(
                .ultraThinMaterial
            )
            .onTapGesture(perform: onDismiss)
            .onRotate { _ in
                onDismiss()
            }
        }
        
        private func onDismiss() {
            withAnimation(.bouncy) {
                scale = 0
            }
            dismiss()
        }
    }
}
