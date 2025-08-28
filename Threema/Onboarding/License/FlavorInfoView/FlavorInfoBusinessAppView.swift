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

struct FlavorInfoBusinessAppView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    var dismiss: () -> Void
    var viewModel = FlavorInfoBusinessAppViewModel()
    
    private enum Constant {
        /// Login Stack
        static let loginSpacing = 20.0
        
        /// Threema Logo
        static let logoBottomPadding = 10.0
        static let logoScaleFactorCompact = 0.6
        static let logoScaleFactorRegular = 0.4
        
        /// Description
        static let descriptionBottomPadding = 10.0
                
        /// More information
        static let moreInfoSpacing = 10.0
    }

    var body: some View {
        GroupBox {
            VStack(spacing: Constant.loginSpacing) {
                VStack(spacing: Constant.loginSpacing) {
                    Image(uiImage: Colors.threemaLogo)
                        .resizable()
                        .scaledToFit()
                        .padding(.bottom, Constant.logoBottomPadding)
                        .apply {
                            if horizontalSizeClass == .compact {
                                $0.frame(maxWidth: UIScreen.main.bounds.width * Constant.logoScaleFactorCompact)
                            }
                            else {
                                $0.frame(maxWidth: UIScreen.main.bounds.width * Constant.logoScaleFactorRegular)
                            }
                        }
                        .accessibilityHidden(true)
                    
                    Text(viewModel.promotionText)
                        .font(.title3.weight(.bold))
                    
                    Text(viewModel.descriptionText)
                        .font(.body)
                }
                .padding(.bottom, Constant.descriptionBottomPadding)
                .accessibilityElement(children: .combine)
                
                Button(viewModel.loginNowText) {
                    dismiss()
                }
                .buttonStyle(.threemaWizardProminentButtonStyle)
                .accessibilityLabel(viewModel.loginNowText)
            }
            .accessibilityElement(children: .contain)
            
            VStack(spacing: Constant.moreInfoSpacing) {
                Text(viewModel.threemaUnusedText)
                    .font(.body)
                
                Button(viewModel.moreInformationText) {
                    viewModel.openWebsiteForFlavorInfo()
                }
                .buttonStyle(.threemaWizardAccentButtonStyle)
                .accessibilityLabel(viewModel.moreInformationText)
            }
            .accessibilityElement(children: .contain)
        }
        .groupBoxStyle(.wizardOpacity)
    }
}
