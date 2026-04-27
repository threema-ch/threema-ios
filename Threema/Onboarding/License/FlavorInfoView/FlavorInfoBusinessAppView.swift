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
                .accessibilityIdentifier("loginButton")
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

#Preview {
    FlavorInfoBusinessAppView { /* no-op */ }
        .padding()
}
