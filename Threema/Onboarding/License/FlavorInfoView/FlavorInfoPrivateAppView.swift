import SwiftUI

struct FlavorInfoPrivateAppView: View {
    var viewModel = FlavorInfoPrivateAppViewModel()
    
    var body: some View {
        GroupBox {
            Text(viewModel.privateAppDescription)
                .font(.body)
            
            Button(viewModel.downloadNow) {
                viewModel.openPrivateAppStoreStoreLink()
            }
            .buttonStyle(.threemaWizardButtonStyle)
            .accessibilityLabel(viewModel.downloadNow)
        }
        .groupBoxStyle(.wizard)
        .accessibilityElement(children: .contain)
    }
}
