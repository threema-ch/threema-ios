import Foundation
import SwiftUI

struct WizardGroupBoxStyle: GroupBoxStyle {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 20.0) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: horizontalSizeClass == .regular ? UIScreen.main.bounds.width - 200.0 : .infinity)
        .padding(.all, 10.0)
    }
}

struct WizardOpacityGroupBoxStyle: GroupBoxStyle {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 40.0) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalSizeClass == .compact ? 20.0 : 40.0)
        .padding(.vertical, 40.0)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.gray.opacity(0.2))
        )
    }
}

extension GroupBoxStyle where Self == WizardGroupBoxStyle {
    static var wizard: Self {
        .init()
    }
}

extension GroupBoxStyle where Self == WizardOpacityGroupBoxStyle {
    static var wizardOpacity: Self {
        .init()
    }
}
