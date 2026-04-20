import SwiftUI

struct MultiDeviceWizardBulletPointView: View {
    let text: String
    let imageName: String
    
    var body: some View {
        
        Label {
            Text(LocalizedStringKey(text))
                .fontWeight(.medium)
        } icon: {
            Image(systemName: imageName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .clear, Color.accentColor)
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardBulletPointView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardBulletPointView(text: "Test", imageName: "pin.fill")
    }
}
