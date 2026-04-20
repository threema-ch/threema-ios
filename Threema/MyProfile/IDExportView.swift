import SwiftUI
import ThreemaMacros

struct IDExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    weak var coordinator: ProfileCoordinator?
    let password: String
    
    @State private var exportString: String?
    @State private var qrImage: Image?
    @State private var includeInBackup = true
    @State private var includeToggleDisabled = true
    
    private var subject: String {
        String.localizedStringWithFormat(
            #localize("id_export_share_item"),
            TargetManager.localizedAppName,
            MyIdentityStore.shared().identity
        )
    }
    
    private var shareItem: String? {
        guard let exportString else {
            return nil
        }
        
        return "\(subject): \(exportString)"
    }
    
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
            if let shareItem, let exportString {
                ToolbarItem(placement: .cancellationAction) {
                    ShareLink(
                        item: shareItem,
                        subject: Text(shareItem),
                        message: Text(exportString)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                DoneButton {
                    donePressed()
                }
            }
        }
        .navigationTitle(#localize("profile_id_export"))
        .interactiveDismissDisabled()
    }
    
    private func checkIncludeToggleDisabled() {
        let mdm = MDMSetup()
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
            do {
                try IdentityBackupStore.saveIdentityBackup(exportString)
            }
            catch {
                NotificationPresenterWrapper.shared.present(type: .saveIdentityBackupFailed)
            }
        }
        else {
            do {
                try IdentityBackupStore.deleteIdentityBackup()
            }
            catch {
                NotificationPresenterWrapper.shared.present(type: .deleteIdentityBackupFailed)
            }
        }
        coordinator.map { $0.dismiss() } ?? dismiss()
    }
}

#Preview {
    IDExportView(password: "")
}
