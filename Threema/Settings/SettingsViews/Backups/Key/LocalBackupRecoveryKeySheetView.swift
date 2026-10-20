import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct LocalBackupRecoveryKeySheetView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var scaledMetric: CGFloat = 1.0
    @ScaledMetric(relativeTo: .title3) private var closeButtonClearance: CGFloat = 60

    let model: LocalBackupRecoveryKeySheetViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20 * scaledMetric) {
                    if isTitleInContent {
                        TitleView(model: model)
                            .padding(.horizontal)
                    }

                    KeyView(model: model)
                    CreateNewKeyView(model: model)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background {
                    ContentHeightReporter(model: model)
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                NavigationBarHeightReporter(model: model)
            }
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    XMarkCancelButton {
                        model.closeButtonTapped()
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if !isTitleInContent {
                TitleView(model: model)
                    .offset(y: 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: model.titleRowHeight)
                    .padding(.leading, 40)
                    .padding(.trailing, closeButtonClearance)
                    .allowsHitTesting(false)
            }
        }
    }

    private var isTitleInContent: Bool {
        dynamicTypeSize > .accessibility4
    }

    private struct TitleView: View {
        let model: LocalBackupRecoveryKeySheetViewModel

        var body: some View {
            Text(model.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private struct KeyView: View {
        let model: LocalBackupRecoveryKeySheetViewModel

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.recoveryKeyTrimmed)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(model.currentKeyLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

                Image(systemName: model.currentKeyIconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 30))
        }
    }

    private struct CreateNewKeyView: View {
        let model: LocalBackupRecoveryKeySheetViewModel

        var body: some View {
            Button {
                model.createNewKeyButtonTapped()
            } label: {
                HStack {
                    Text(model.createNewKeyLabel)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    Image(systemName: model.createNewKeyIconName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// Reports the height the content needs, so that the sheet can size its detent to it.
    private struct ContentHeightReporter: View {
        let model: LocalBackupRecoveryKeySheetViewModel

        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height, initial: true) { _, height in
                        model.contentHeightChanged(height)
                    }
            }
        }
    }

    private struct NavigationBarHeightReporter: View {
        let model: LocalBackupRecoveryKeySheetViewModel

        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.safeAreaInsets.top, initial: true) { _, height in
                        model.navigationBarHeightChanged(height)
                    }
            }
        }
    }
}
