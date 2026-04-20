import Foundation
import SwiftUI

struct StorageManagementGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
        }
        .buttonStyle(.bordered)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(UIColor.secondarySystemGroupedBackground.color)
        )
    }
}

extension GroupBoxStyle where Self == StorageManagementGroupBoxStyle {
    static var storageManagement: Self {
        .init()
    }
}
