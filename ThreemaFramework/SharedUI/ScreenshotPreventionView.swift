import SwiftUI
import ThreemaMacros

public struct ScreenshotPreventionView: View {

    private static var resolvedColorScheme: ColorScheme {
        switch UserSettings.shared().interfaceStyle {
        case UIUserInterfaceStyle.light.rawValue:
            .light
        case UIUserInterfaceStyle.dark.rawValue:
            .dark
        default:
            UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
    }
    
    public init() { }

    public var body: some View {
        ZStack {
            Color(.systemBackground)
            
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
                    .foregroundStyle(.primary)
                    .padding()

                Text(#localize("screenshot_prevention_info"))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                Spacer()
            }
            .safeAreaPadding(.top, 24)
            .padding([.top, .bottom])
            .padding([.leading, .trailing], 50)
            .multilineTextAlignment(.center)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, Self.resolvedColorScheme)
    }
}

#if DEBUG

    #Preview {
        ScreenshotPreventionView()
    }

#endif
