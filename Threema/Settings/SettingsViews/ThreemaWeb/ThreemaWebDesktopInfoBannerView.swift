import SwiftUI
import ThreemaMacros

struct ThreemaWebDesktopInfoBannerView: View {
    let onTap: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.primary)
                    Text(String.localizedStringWithFormat(
                        #localize("settings_threema_web_desktop_banner_title"),
                        TargetManager.localizedAppName
                    ))
                    .bold()
                    Spacer()
                }
                
                Text(#localize("settings_threema_web_desktop_banner_message"))
            }
            
            Button {
                dismissAction()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(Colors.textProminentButton.color)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor)
        .cornerRadius(10)
        .background(Colors.backgroundView.color)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ThreemaWebDesktopInfoBannerView(onTap: { }, dismissAction: { })
}
