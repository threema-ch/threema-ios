import Foundation
import SwiftUI

extension ButtonStyle where Self == ThreemaWizardButtonStyle {
    static var threemaWizardButtonStyle: ThreemaWizardButtonStyle { .init() }
    static var threemaWizardAccentButtonStyle: ThreemaWizardButtonStyle {
        .init(textColor: Color.accentColor)
    }
}

struct ThreemaWizardButtonStyle: ButtonStyle {
    var textColor = Color(.label)
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8.0) {
            Image(systemName: "arrow.forward")
                .imageScale(.medium)
            configuration.label
                .font(.headline)
                .textCase(.uppercase)
                .accessibilityElement()
        }
        .foregroundStyle(textColor)
    }
}
