import SwiftUI
import ThreemaFramework

struct LocalBackupRecoveryKeyView: View {
    private static let bottomViewID = "bottomView"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric private var scaledMetric: CGFloat = 1.0
    @Bindable var model: LocalBackupRecoveryKeyViewModel

    private let headerHeight = DotHeaderView.defaultHeight
    private let headerOverlap = DotHeaderView.defaultOverlap

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    DotHeaderView(
                        icon: DotHeaderView.Icon(name: model.headerIconName, color: .accentColor),
                        dotColor: .accentColor.opacity(0.3),
                        height: headerHeight
                    )

                    VStack(spacing: 10 * scaledMetric) {
                        BackupHeaderView(
                            step: model.stepLabel,
                            title: model.headerTitle,
                            subtitle: model.headerSubtitle,
                            backdrop: Color.listsBackgroundColor
                        )
                        .padding(.bottom, 20 * scaledMetric)

                        KeyView(model: model)

                        BackupInfoView(
                            title: nil,
                            content: model.warning,
                            textColor: .accentColor,
                            textFont: .callout,
                            iconName: model.warningIconName,
                            iconColor: .accentColor,
                            backgroundColor: Color(.secondary)
                        )
                        .padding(.bottom, 20 * scaledMetric)

                        if isBottomViewInlined {
                            BottomView(model: model, isInlined: true)
                                .id(Self.bottomViewID)
                        }
                    }
                    .safeAreaPadding(.horizontal, 20)
                    .padding(.top, -headerHeight * headerOverlap / scaledMetric)
                }
            }
            .background(Color.listsBackgroundColor.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !isBottomViewInlined {
                    BottomView(model: model, isInlined: false)
                        .padding(.horizontal, 22)
                }
            }
            .onAppear {
                model.onAppear()
            }
            .onDisappear {
                model.onDisappear()
            }
            .onChange(of: verticalSizeClass) {
                scrollToBottom(using: proxy)
            }
            .alert(
                model.deleteAlertTitle,
                isPresented: $model.showDeleteKeyAlert
            ) {
                VStack {
                    Button(model.deleteLabel, role: .destructive) {
                        model.deleteKeyConfirmed()
                    }

                    Button(model.cancelButtonTitle, role: .cancel) { }
                }
            } message: {
                Text(verbatim: model.deleteAlertMessage)
            }
            .alert(
                model.createNewKeyAlertTitle,
                isPresented: $model.showCreateNewKeyAlert
            ) {
                VStack {
                    Button(model.createNewKeyLabel, role: {
                        if #available(iOS 26.0, *) {
                            .confirm
                        }
                        else {
                            nil
                        }
                    }()) {
                        model.createNewKeyConfirmed()
                    }

                    Button(model.cancelButtonTitle, role: .cancel) { }
                }
            } message: {
                Text(verbatim: model.createNewKeyAlertMessage)
            }
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        Task {
            // Wait for SwiftUI to finish the relayout the size-class change triggers before scrolling, otherwise
            // `scrollTo` runs against the stale layout and doesn't reach the bottom view.
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation {
                proxy.scrollTo(Self.bottomViewID, anchor: .bottom)
            }
        }
    }

    private var isBottomViewInlined: Bool {
        guard let horizontalSizeClass, let verticalSizeClass else {
            return true
        }

        switch (horizontalSizeClass, verticalSizeClass) {
        case (_, .compact):
            return true

        case (.compact, .regular):
            return dynamicTypeSize >= DynamicTypeSize.xxLarge

        case (.regular, .regular):
            return dynamicTypeSize >= DynamicTypeSize.accessibility1

        default:
            return true
        }
    }

    private struct KeyView: View {
        @ScaledMetric private var scaledMetric: CGFloat = 1.0

        let model: LocalBackupRecoveryKeyViewModel

        var body: some View {
            SectionCard {
                VStack(spacing: 20 * scaledMetric) {
                    GridView(model: model)
                    ActionsView(model: model)
                }
                .padding(.vertical, 8 * scaledMetric)
            } header: {
                Text(model.currentKeyLabel)
            } footer: {
                if model.hasDefaultRecoveryKey, let usage = model.recoveryKeyUsage {
                    Text(usage)
                }
            }
        }

        private struct GridView: View {
            @Environment(\.dynamicTypeSize) private var dynamicTypeSize
            @Environment(\.horizontalSizeClass) private var horizontalSizeClass
            @Environment(\.verticalSizeClass) private var verticalSizeClass
            @ScaledMetric private var scaledMetric: CGFloat = 1.0

            let model: LocalBackupRecoveryKeyViewModel

            var body: some View {
                Grid(horizontalSpacing: 0, verticalSpacing: 24 * scaledMetric) {
                    ForEach(model.keyRows(columnsPerRow: columnsPerRow)) { row in
                        GridRow {
                            ForEach(row.cells) { cell in
                                Text(cell.text)
                                    .font(.callout.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            private var columnsPerRow: Int {
                guard let horizontalSizeClass, let verticalSizeClass else {
                    return 1
                }

                return switch (horizontalSizeClass, verticalSizeClass) {
                case (_, .compact):
                    dynamicTypeSize > .accessibility4 ? 2 : 4

                case (.compact, .regular):
                    if dynamicTypeSize > .accessibility2 {
                        1
                    }
                    else if dynamicTypeSize > .xxxLarge {
                        2
                    }
                    else {
                        4
                    }

                case (.regular, .regular):
                    4

                default:
                    1
                }
            }
        }

        private struct ActionsView: View {
            let model: LocalBackupRecoveryKeyViewModel

            var body: some View {
                HStack(spacing: 16) {
                    if model.hasDefaultRecoveryKey {
                        CapsuleButton(
                            iconName: model.deleteIconName,
                            label: model.deleteLabel,
                            style: .bordered(.red),
                            fillsAvailableWidth: true,
                            action: model.deleteKeyButtonTapped
                        )
                    }

                    CapsuleButton(
                        iconName: model.copyIconName,
                        label: model.copyButtonTitle,
                        style: .filled,
                        fillsAvailableWidth: model.hasDefaultRecoveryKey,
                        action: model.copyKeyButtonTapped
                    )
                }
                .transaction { $0.disablesAnimations = true } // disable the animation of the icon movement
            }

            private struct CapsuleButton: View {
                @ScaledMetric private var scaledMetric: CGFloat = 1.0

                let iconName: String
                let label: String
                let style: Style
                let fillsAvailableWidth: Bool
                let action: () -> Void

                enum Style {
                    case filled
                    case bordered(Color)
                }

                var body: some View {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            Image(systemName: iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14 * scaledMetric, height: 14 * scaledMetric)

                            Text(label)
                                .font(.footnote)
                        }
                        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
                        .foregroundStyle(contentColor)
                        .padding(10 * scaledMetric)
                        .background {
                            switch style {
                            case .filled:
                                Capsule().fill(Color(.systemGray5))
                            case let .bordered(color):
                                Capsule().fill(color.opacity(0.2))
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .tint(contentColor)
                }

                private var contentColor: Color {
                    switch style {
                    case .filled:
                        Color(.label)
                    case let .bordered(color):
                        color
                    }
                }
            }
        }
    }

    private struct BottomView: View {
        let model: LocalBackupRecoveryKeyViewModel
        let isInlined: Bool

        var body: some View {
            ThreemaButton(
                title: model.hasDefaultRecoveryKey ? model.createKeyLabel : model.saveButtonTitle,
                style: .borderedProminent,
                size: .fullWidth
            ) {
                if model.hasDefaultRecoveryKey {
                    model.createNewKeyButtonTapped()
                }
                else {
                    model.saveButtonTapped()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#if DEBUG
    #Preview(LocalBackupRecoveryKeyView.Stance.generatedKey.title) {
        LocalBackupRecoveryKeyView.Stance.generatedKey.view
    }

    #Preview(LocalBackupRecoveryKeyView.Stance.copiedKey.title) {
        LocalBackupRecoveryKeyView.Stance.copiedKey.view
    }

    #Preview(LocalBackupRecoveryKeyView.Stance.defaultKey.title) {
        LocalBackupRecoveryKeyView.Stance.defaultKey.view
    }

    #Preview(LocalBackupRecoveryKeyView.Stance.alertRemove.title) {
        LocalBackupRecoveryKeyView.Stance.alertRemove.view
    }

    #Preview(LocalBackupRecoveryKeyView.Stance.alertRemove.title) {
        LocalBackupRecoveryKeyView.Stance.alertCreate.view
    }

    import DataBackup

    extension LocalBackupRecoveryKeyView {
        enum Stance: PreviewCase {
            case generatedKey
            case copiedKey
            case defaultKey
            case alertRemove
            case alertCreate

            var title: String {
                switch self {
                case .generatedKey: "Recovery Key - Generated"
                case .copiedKey: "Recovery Key - Copied Key"
                case .defaultKey: "Recovery Key - Default"
                case .alertRemove: "Recovery Key - Alert Remove key"
                case .alertCreate: "Recovery Key - Alert Create new key"
                }
            }

            @MainActor
            private var modelGeneratedKey: LocalBackupRecoveryKeyViewModel {
                LocalBackupRecoveryKeyViewModel(
                    manager: BackupCreateManagerMock(currentRecoveryKey: .mockGeneratedKey)
                )
            }

            @MainActor
            private var modelDefaultKey: LocalBackupRecoveryKeyViewModel {
                LocalBackupRecoveryKeyViewModel(
                    manager: BackupCreateManagerMock(currentRecoveryKey: .mockDefaultKey)
                )
            }

            @MainActor var view: some View {
                switch self {
                case .generatedKey:
                    PushedPreview {
                        LocalBackupRecoveryKeyView(model: modelGeneratedKey)
                    }

                case .copiedKey:
                    PushedPreview {
                        LocalBackupRecoveryKeyView(
                            model: {
                                let model = modelGeneratedKey
                                model.onAppear()
                                model.copyKeyButtonTapped()
                                return model
                            }()
                        )
                    }

                case .defaultKey:
                    PushedPreview {
                        LocalBackupRecoveryKeyView(model: modelDefaultKey)
                    }

                case .alertRemove:
                    PushedPreview {
                        let model = modelDefaultKey
                        LocalBackupRecoveryKeyView(model: model)
                            .task {
                                model.showDeleteKeyAlert = true
                            }
                    }

                case .alertCreate:
                    PushedPreview {
                        let model = modelDefaultKey
                        LocalBackupRecoveryKeyView(model: model)
                            .task {
                                model.showCreateNewKeyAlert = true
                            }
                    }
                }
            }
        }
    }

#endif
