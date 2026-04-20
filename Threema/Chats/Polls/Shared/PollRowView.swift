import SwiftUI
import ThreemaMacros

struct PollRowView: View {
    let title: String?
    let creator: String?
    let created: Date?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading) {
                Text(title.flatMap { $0.isEmpty ? nil : $0 } ?? #localize("unknown"))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack {
                    if let creator {
                        Text(creator)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let created {
                        Text(created.formatted(date: .abbreviated, time: .omitted))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("PollRowViewButton")
    }
}
