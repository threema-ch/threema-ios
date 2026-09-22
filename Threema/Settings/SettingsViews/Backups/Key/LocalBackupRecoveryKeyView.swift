import SwiftUI
import ThreemaFramework

struct LocalBackupRecoveryKeyView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Bindable var model: LocalBackupRecoveryKeyViewModel

    private static let bottomViewID = "bottomView"

    var body: some View {
        ScrollViewReader { proxy in
            List {
                HeaderView(model: model)

                BackupInfoView(
                    title: model.info?.title,
                    content: model.info?.content,
                    textColor: .primary,
                    textFont: .callout,
                    iconName: model.errorIconName,
                    iconColor: .red
                )

                KeyView(model: model)

                if isBottomViewInlined {
                    BottomView(model: model, isInlined: true)
                        .id(Self.bottomViewID)
                }
            }
            .listSectionSpacing(.compact)
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !isBottomViewInlined {
                    BottomView(model: model, isInlined: false)
                        .padding(.horizontal, 28)
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

    private struct HeaderView: View {
        let model: LocalBackupRecoveryKeyViewModel
        
        var body: some View {
            BackupHeaderView(
                icon: .init(symbolName: model.headerSymbolName, color: .blue, rotationDegrees: 30),
                step: model.stepLabel,
                title: model.keyTitle,
                subtitle: model.keyDescription
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    private struct KeyView: View {
        @ScaledMetric private var scaledMetric: CGFloat = 1.0

        let model: LocalBackupRecoveryKeyViewModel

        var body: some View {
            Section {
                VStack(spacing: 12 * scaledMetric) {
                    CurrentKeyView(model: model)
                    GridView(model: model)
                    UsageView(model: model)
                    ActionsView(model: model)
                }
            }
        }

        private struct CurrentKeyView: View {
            let model: LocalBackupRecoveryKeyViewModel

            var body: some View {
                if model.hasDefaultRecoveryKey {
                    Text(model.currentKeyLabel)
                        .font(.callout)
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(Color(.systemBackground))
                        .background(Color.accentColor, in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                Grid(verticalSpacing: 12 * scaledMetric) {
                    ForEach(model.keyRows(columnsPerRow: columnsPerRow)) { row in
                        GridRow {
                            ForEach(row.cells) { cell in
                                Text(attributedCode(cell.text))
                                    .font(.callout)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            /// Number of key chunks shown per row for the current size class and Dynamic Type setting.
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

            private func attributedCode(_ code: String) -> AttributedString {
                var attributed = AttributedString(code)

                for run in code.ranges(of: /\d+/) {
                    if let range = Range(run, in: attributed) {
                        attributed[range].foregroundColor = Color.accentColor
                    }
                }

                return attributed
            }
        }

        private struct UsageView: View {
            let model: LocalBackupRecoveryKeyViewModel

            var body: some View {
                if model.hasDefaultRecoveryKey, let value = model.recoveryKeyUsage {
                    Text(value)
                        .font(.footnote).bold()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }

        private struct ActionsView: View {
            let model: LocalBackupRecoveryKeyViewModel

            var body: some View {
                VStack(spacing: 16) {
                    CapsuleButton(
                        iconName: model.copyIconName,
                        label: model.copyButtonTitle,
                        style: .filled,
                        action: model.copyKeyButtonTapped
                    )

                    if model.hasDefaultRecoveryKey {
                        CapsuleButton(
                            iconName: model.deleteIconName,
                            label: model.deleteLabel,
                            style: .bordered(.red),
                            action: model.deleteKeyButtonTapped
                        )
                    }
                }
                .transaction { $0.disablesAnimations = true } // disable the animation of the icon movement
            }

            private struct CapsuleButton: View {
                @ScaledMetric private var scaledMetric: CGFloat = 1.0

                let iconName: String
                let label: String
                let style: Style
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
                                .frame(width: 16 * scaledMetric, height: 16 * scaledMetric)

                            Text(label)
                                .font(.footnote)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(contentColor)
                        .padding(6 * scaledMetric)
                        .background {
                            switch style {
                            case .filled:
                                Capsule().fill(Color(.systemGray5))
                            case let .bordered(color):
                                Capsule().strokeBorder(color, lineWidth: 1)
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
            if model.hasDefaultRecoveryKey {
                CreateNewKeyView(model: model, isInlined: isInlined)
            }
            else {
                SaveKeyView(model: model)
            }
        }

        private struct SaveKeyView: View {
            @ScaledMetric private var scaledMetric: CGFloat = 1
            let model: LocalBackupRecoveryKeyViewModel

            var body: some View {
                VStack(spacing: 24 * scaledMetric) {
                    BackupInfoView(
                        title: nil,
                        content: model.warning,
                        textColor: Color.accentColor,
                        textFont: .callout,
                        iconName: model.warningIconName,
                        iconColor: Color.accentColor
                    )

                    ThreemaButton(
                        title: model.saveButtonTitle,
                        style: .borderedProminent,
                        size: .fullWidth
                    ) {
                        model.saveButtonTapped()
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }

        private struct CreateNewKeyView: View {
            let model: LocalBackupRecoveryKeyViewModel
            let isInlined: Bool

            var body: some View {
                if isInlined {
                    Section {
                        Button {
                            model.createNewKeyButtonTapped()
                        } label: {
                            content
                        }
                    }
                }
                else {
                    Button {
                        model.createNewKeyButtonTapped()
                    } label: {
                        content
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
            }

            private var content: some View {
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.createKeyLabel)
                            .font(.callout)
                            .foregroundStyle(Color.primary)
                        Text(model.createKeyDescription)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: model.createKeyIconName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
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
