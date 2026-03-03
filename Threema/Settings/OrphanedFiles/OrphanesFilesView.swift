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

struct OrphanedFilesView: View {
    typealias Strings = OrphanedFilesViewModel.Strings

    @ObservedObject var model: OrphanedFilesViewModel

    var body: some View {
        List {
            cleanupSection()
            orphanedFilesSection()
            trashBinFilesSection()
            logAppFilesSection()
        }
        .loadingOverlay(model.isLoading)
        .confirmationDialog(
            Strings.Confirmation.title,
            isPresented: $model.isShowingBinConfirmationDialog,
            titleVisibility: .visible,
            actions: confirmationDialogActions
        )
        .onAppear {
            Task { await model.loadInitialData() }
        }
        .disabled(model.isLoading)
    }

    @ViewBuilder
    private func cleanupSection() -> some View {
        Section {
            Text(Strings.DeleteOrphanedFiles.description)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.leading)
                .padding(.vertical)
                .frame(maxWidth: .infinity)

        } header: {
            Text(Strings.DeleteOrphanedFiles.header)
        }
    }

    @ViewBuilder
    private func orphanedFilesSection() -> some View {
        Section {
            Button(Strings.OrphanedFiles.moveButton) {
                Task { await model.moveOrphanedFilesToBin() }
            }
            .tint(Color(uiColor: Colors.textLink))
            .disabled(!model.orphanedFilesSectionEnabled)
            .frame(maxWidth: .infinity)
        } header: {
            Text(Strings.OrphanedFiles.header)
        } footer: {
            Text(model.orphanedFilesSectionFooter)
        }
    }

    @ViewBuilder
    private func trashBinFilesSection() -> some View {
        Section {
            Button {
                Task { await model.restoreTrashBin() }
            } label: {
                Text(Strings.TrashBin.restoreButton)
                    .frame(maxWidth: .infinity, alignment: .center)
            }.alignmentGuide(.listRowSeparatorLeading) { dimensions in
                dimensions[.leading]
            }
            .tint(Color(uiColor: Colors.textLink))
            .disabled(!model.trashBinSectionEnabled)

            Button {
                model.emptyTrashBin()
            } label: {
                Text(Strings.TrashBin.deleteButton)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .tint(Color(uiColor: .systemRed))
            .disabled(!model.trashBinSectionEnabled)
        } header: {
            Text(Strings.TrashBin.header)
        } footer: {
            Text(model.trashBinSectionFooter)
        }
    }

    @ViewBuilder
    private func logAppFilesSection() -> some View {
        Section(Strings.LogFiles.header) {
            Button(Strings.LogFiles.logButton) {
                Task { await model.logAppFiles() }
            }
            .tint(Color(uiColor: Colors.textLink))
            .disabled(!model.validationLoggingEnabled)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func confirmationDialogActions() -> some View {
        Button(role: .destructive) {
            Task { await model.emptyTrashBinConfirmed() }
        } label: {
            Text(Strings.Confirmation.deleteButton)
        }
        Button(role: .cancel) {
            model.isShowingBinConfirmationDialog = false
        } label: {
            Text(Strings.Confirmation.cancelButton)
        }
    }
}

import ThreemaFramework

#Preview("Non empty") {
    OrphanedFilesView(
        model: .init(
            loggingFilesManager: .noop,
            orphanedFilesManager: .nonEmpty,
            trashBinManager: .nonEmpty,
            validationLoggingEnabled: true
        )
    )
}

#Preview("Empty") {
    OrphanedFilesView(
        model: .init(
            loggingFilesManager: .noop,
            orphanedFilesManager: .empty,
            trashBinManager: .empty,
            validationLoggingEnabled: false
        )
    )
}

struct OrphanedFilesManagerMock: OrphanedFilesManagerProtocol {
    let orphaned: [String]
    let totalCount: Int

    func getOrphanedFilesData() -> (orphaned: [String], totalCount: Int) { (orphaned, totalCount) }
}

extension OrphanedFilesManagerProtocol where Self == OrphanedFilesManagerMock {
    static var empty: OrphanedFilesManagerProtocol {
        OrphanedFilesManagerMock(orphaned: [], totalCount: 100)
    }

    static var nonEmpty: OrphanedFilesManagerProtocol {
        OrphanedFilesManagerMock(orphaned: ["a", "b", "c", "d"], totalCount: 10)
    }
}

struct TrashBinManagerMock: TrashBinManagerProtocol {
    let files: [String]
    let size: Int64

    func getTrashBinFilesData() -> (files: [String], size: Int64) { (files, size) }

    func moveToTrashBin(_ files: [String]) { }

    func restoreTrashBin() { }

    func emptyTrashBin() { }
}

extension TrashBinManagerProtocol where Self == TrashBinManagerMock {
    static var empty: TrashBinManagerProtocol {
        TrashBinManagerMock(files: [], size: 0)
    }

    static var nonEmpty: TrashBinManagerProtocol {
        TrashBinManagerMock(files: ["a", "b", "c", "d"], size: 1_000_000)
    }
}

struct LoggingFilesManagerMock: LoggingFilesManagerProtocol {
    func logDirectoriesAndFiles() { }
}

extension LoggingFilesManagerProtocol where Self == LoggingFilesManagerMock {
    static var noop: LoggingFilesManagerProtocol {
        LoggingFilesManagerMock()
    }
}
