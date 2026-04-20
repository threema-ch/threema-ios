import SwiftUI

struct FlavorInfoView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var dismiss: () -> Void
    
    private enum Constant {
        static let spacing = 40.0
        static let padding = 24.0
        static let maxWidthRegular = 800.0
        static let topPaddingCompact = 0.0
        static let topPaddingRegular = 40.0
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    FlavorInfoBusinessAppView(dismiss: dismiss)
                        .padding(.bottom, Constant.spacing)
                    
                    FlavorInfoPrivateAppView()
                    
                    Spacer(minLength: Constant.spacing)
                    
                    Text(ThreemaUtility.appAndBuildVersionPretty)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .copyLabel(value: ThreemaUtility.appAndBuildVersion)
                }
                .padding(Constant.padding)
                .apply {
                    if horizontalSizeClass == .compact {
                        $0.padding(.top, Constant.topPaddingCompact)
                            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                    else {
                        $0.padding(.top, Constant.topPaddingRegular)
                            .frame(maxWidth: Constant.maxWidthRegular, minHeight: proxy.size.height)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxWidth: .infinity)
            .background(.black)
            .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - BusinessAppView

#Preview {
    FlavorInfoView {
        // do nothing
    }
}
