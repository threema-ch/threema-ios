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

struct IDExportView: View {
    weak var coordinator: ProfileCoordinator?
    let password: String
    
    @State private var exportString: String?
    @State private var qrImage: Image?
    @State private var includeInBackup = true
    @State private var includeToggleDisabled = true
    
    var body: some View {
        List {
            if let exportString, let qrImage {
                Section {
                    Toggle(#localize("id_export_include_in_device_backup_label"), isOn: $includeInBackup)
                        .disabled(includeToggleDisabled)
                }
                footer: {
                    if includeToggleDisabled {
                        Text(#localize("disabled_by_device_policy"))
                    }
                    else {
                        Text(includeInBackup ? #localize("backup_include") : #localize("backup_exclude"))
                    }
                }
                
                Section {
                    VStack {
                        Text(exportString)
                            .font(.system(.title3, design: .monospaced))
                            .lineLimit(4)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 350)
                            .padding()
                            .onTapGesture {
                                UIPasteboard.general.string = exportString
                                NotificationPresenterWrapper.shared.present(type: .copySuccess)
                            }
                        Divider()
                        qrImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                header: {
                    Text(#localize("id_export_your_export_label"))
                }
                footer: {
                    Text(#localize("backup_footer"))
                }
            }
            else {
                ProgressView()
                    .task {
                        checkIncludeToggleDisabled()
                        generateExport()
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    donePressed()
                } label: {
                    Text(#localize("Done"))
                }
            }
        }
        .navigationTitle(#localize("profile_id_export"))
        .interactiveDismissDisabled()
    }
    
    private func checkIncludeToggleDisabled() {
        let mdm = MDMSetup(setup: false)
        if mdm?.disableBackups() ?? false {
            includeToggleDisabled = true
            includeInBackup = false
        }
        else {
            includeToggleDisabled = false
        }
    }
    
    private func generateExport() {
        exportString = BusinessInjector.ui.myIdentityStore.backupIdentity(withPassword: password)
        // Will not be shown anyways when export string is nil
        if let exportString {
            qrImage = Image(uiImage: QRCodeGenerator.generateQRCode(for: exportString, size: 300))
        }
    }
    
    private func donePressed() {
        guard let exportString else {
            fatalError()
        }
        if includeInBackup {
            IdentityBackupStore.saveIdentityBackup(exportString)
        }
        else {
            IdentityBackupStore.deleteIdentityBackup()
        }
        coordinator?.dismiss()
    }
}

#Preview {
    IDExportView(password: "")
}
