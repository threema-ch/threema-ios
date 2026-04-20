import Foundation
import SwiftUI

/// `LabelStyle` where the icon is trailing to title.
struct TrailingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}
