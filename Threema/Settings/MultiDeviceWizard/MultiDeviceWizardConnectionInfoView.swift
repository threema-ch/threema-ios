import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct MultiDeviceWizardConnectionInfoView: View {
    var body: some View {
       
        HStack {
            VStack(alignment: .leading) {
                Text(#localize("md_wizard_connection_info"))
            }
            Spacer()
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: Colors.backgroundWizardBox))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - Preview

struct MultiDeviceWizardConnectionInfoView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardConnectionInfoView()
    }
}
