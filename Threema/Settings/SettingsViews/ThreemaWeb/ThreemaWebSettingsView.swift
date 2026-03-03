//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import ThreemaMacros

struct ThreemaWebSettingsView: View {
    @StateObject private var viewModel = ThreemaWebSettingsViewModel()

    var body: some View {
        List {
            header
            webToggle
            sessions
        }
        .tint(.accentColor)
        .navigationTitle(viewModel.screenTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.scan()
                } label: {
                    Image(systemName: viewModel.scanButtonIconName)
                }
                .disabled(!viewModel.canScan)
            }
        }
        .onAppear { viewModel.load() }
        .confirmationDialog(
            viewModel.confirmationDialogTitle,
            isPresented: $viewModel.showSessionActions,
            titleVisibility: .visible
        ) {
            if let buttonTitle = viewModel.sessionToggleButtonTitle {
                Button(buttonTitle) {
                    viewModel.startOrStopSelectedSession()
                }
                Button(viewModel.renameButtonTitle) {
                    viewModel.askRename()
                }
                Button(viewModel.deleteButtonTitle, role: .destructive) {
                    viewModel.deleteSelected()
                }
            }
            Button(viewModel.cancelButtonTitle, role: .cancel) {
                viewModel.showSessionActions = false
            }
        }
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
                NotificationCenter.default.post(name: .showDesktopSettings, object: nil)
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
    var sessions: some View {
        if !viewModel.sessions.isEmpty {
            Section {
                ForEach(viewModel.sessions, id: \.objectID) { session in
                    ThreemaWebSettingsSessionView(session: session) {
                        viewModel.presentActions(for: session)
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
