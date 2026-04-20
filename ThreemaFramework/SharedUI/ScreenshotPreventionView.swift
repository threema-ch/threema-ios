import SwiftUI
import ThreemaMacros

public struct ScreenshotPreventionView: View {

    public init() { }

    public var body: some View {
        ZStack {
            Colors.textInverted.color
            
            VStack(spacing: 8) {
                Image(uiImage: Colors.threemaLogo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 150)
                    .padding()

                Spacer()

                Image(systemName: "eye.slash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .padding()

                Text(#localize("screenshot_prevention_info"))
                    .font(.title3)
                    .fontWeight(.medium)
                
                Spacer()
                Spacer()
            }
            .safeAreaPadding(.top, 24)
            .padding([.top, .bottom])
            .padding([.leading, .trailing], 50)
            .multilineTextAlignment(.center)
        }
        .ignoresSafeArea()
    }
}

#if DEBUG

    #Preview {
        ScreenshotPreventionView()
    }

#endif
