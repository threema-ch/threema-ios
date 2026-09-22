import SwiftUI
import ThreemaMacros

struct ThreemaWebSettingsView: View {
    private let showCloseButton: Bool

    @StateObject private var viewModel = ThreemaWebSettingsViewModel()

    init(showCloseButton: Bool = false) {
        self.showCloseButton = showCloseButton
    }

    var body: some View {
        List {
            header
            webToggle
            sessions
        }
        .tint(.accentColor)
        .navigationTitle(viewModel.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The close button goes where the back button sits when this view is pushed, so the
            // scan button keeps its trailing spot in both presentations (the section footer also
            // points to the upper right corner)
            if showCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    XMarkCancelButton {
                        viewModel.close()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(
                    viewModel.scanButtonTitle,
                    systemImage: viewModel.scanButtonIconName,
                    action: viewModel.scan
                )
                .disabled(!viewModel.canScan)
            }
        }
        .onAppear { viewModel.load() }
        .alert(viewModel.alertDialogTitle, isPresented: $viewModel.showRenamePrompt) {
            TextField(viewModel.defaultSessionName, text: $viewModel.renameText)
            Button(viewModel.saveButtonTitle) {
                viewModel.confirmRename()
            }
            Button(viewModel.cancelButtonTitle, role: .cancel) {
                viewModel.showRenamePrompt = false
            }
        }
        .alert(
            viewModel.alertTitle ?? "",
            isPresented: $viewModel.showAlert
        ) {
            Button(viewModel.okButtonTitle, role: .cancel) {
                viewModel.showAlert = false
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
    
    @ViewBuilder
    var header: some View {
        if viewModel.showDesktopInfoBanner {
            ThreemaWebDesktopInfoBannerView {
                viewModel.showDesktop()
            } dismissAction: {
                viewModel.dismissBanner()
            }
            .listRowInsets(.init())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }
    
    @ViewBuilder
    var webToggle: some View {
        Section {
            Toggle(
                isOn: Binding(
                    get: { viewModel.isWebEnabled },
                    set: viewModel.toggleWeb
                )
            ) {
                Text(viewModel.sessionTitle)
            }
            .disabled(!viewModel.canScan)
        } footer: {
            Text(viewModel.webToggleFooterLabel)
        }
    }
    
    @ViewBuilder
    var sessionActions: some View {
        if let buttonTitle = viewModel.sessionToggleButtonTitle {
            Button(buttonTitle) {
                viewModel.startOrStopSelectedSession()
            }
        }
        Button(viewModel.renameButtonTitle) {
            viewModel.askRename()
        }
        Button(viewModel.deleteButtonTitle, role: .destructive) {
            viewModel.deleteSelected()
        }
        Button(viewModel.cancelButtonTitle, role: .cancel) {
            viewModel.showSessionActions = false
        }
    }

    @ViewBuilder
    var sessions: some View {
        if !viewModel.sessions.isEmpty {
            Section {
                ForEach(viewModel.sessions, id: \.objectID) { session in
                    ThreemaWebSettingsSessionView(session: session) {
                        viewModel.presentActions(for: session)
                    }
                    // Attached to the row, so the dialog is anchored to the tapped session and not to the top of the
                    // list (where the Threema Web toggle is)
                    .confirmationDialog(
                        viewModel.confirmationDialogTitle,
                        isPresented: Binding(
                            get: {
                                viewModel.showSessionActions
                                    && viewModel.selectedSession?.objectID == session.objectID
                            },
                            set: { isPresented in
                                if !isPresented {
                                    viewModel.showSessionActions = false
                                }
                            }
                        ),
                        titleVisibility: .visible
                    ) {
                        sessionActions
                    }
                }
                .onDelete { indexSet in
                    viewModel.deleteSessions(at: indexSet)
                }
            } header: {
                Text(viewModel.addSessionHeaderLabel)
            } footer: {
                Text(viewModel.addSessionFooterLabel)
            }
        }
        else {
            Section {
                EmptyView()
            } footer: {
                Text(viewModel.addSessionFooterLabel)
            }
        }
    }
}
