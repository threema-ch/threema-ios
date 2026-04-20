import Foundation
import SwiftUI

extension ButtonStyle where Self == ThreemaWizardProminentButtonStyle {
    static var threemaWizardProminentButtonStyle: ThreemaWizardProminentButtonStyle { .init() }
}

struct ThreemaWizardProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8.0) {
            Image(systemName: "arrow.forward")
                .imageScale(.medium)
            configuration.label
                .font(.headline)
                .textCase(.uppercase)
        }
        .padding(EdgeInsets(top: 12.0, leading: 16.0, bottom: 12.0, trailing: 16.0))
        .background(Color.accentColor)
        .foregroundStyle(Colors.textProminentButtonWizard.color)
        .clipShape(Capsule(style: .continuous))
        .accessibilityElement()
    }
}
