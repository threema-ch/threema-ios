import SwiftUI
import ThreemaFramework

@MainActor
protocol LearnMoreSheetModel {
    var headerIconName: String { get }
    var title: String { get }
    var content: String { get }
}

struct LearnMoreSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let headerHeight = DotHeaderView.defaultHeight
    private let headerOverlap = DotHeaderView.defaultOverlap

    private let headerIconName: String
    private let title: String
    private let content: String

    init(headerIconName: String, title: String, content: String) {
        self.headerIconName = headerIconName
        self.title = title
        self.content = content
    }

    init(model: some LearnMoreSheetModel) {
        self.init(
            headerIconName: model.headerIconName,
            title: model.title,
            content: model.content
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: horizontalAlignment, spacing: 0) {
                    DotHeaderView(
                        icon: DotHeaderView.Icon(name: headerIconName, color: .accentColor),
                        dotColor: .accentColor.opacity(0.3),
                        height: headerHeight
                    )

                    VStack(alignment: horizontalAlignment, spacing: 24) {
                        Text(title)
                            .font(.title.bold())
                            .multilineTextAlignment(textAlignment)
                            .frame(maxWidth: .infinity)
                            .accessibilityAddTraits(.isHeader)

                        Text(content)
                            .font(.callout)
                            .multilineTextAlignment(textAlignment)
                            .foregroundStyle(.gray600)
                            .frame(maxWidth: .infinity)
                    }
                    .safeAreaPadding(.horizontal, 44)
                    .padding(.top, -headerHeight * headerOverlap)
                }
            }
            .background(Color.listsBackgroundColor.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DoneButton {
                        dismiss()
                    }
                }
            }
        }
    }

    private var horizontalAlignment: HorizontalAlignment {
        dynamicTypeSize >= .accessibility1 ? .leading : .center
    }

    private var textAlignment: TextAlignment {
        dynamicTypeSize >= .accessibility1 ? .leading : .center
    }
}
