import CocoaLumberjackSwift
import Combine
import SwiftUI
import ThreemaMacros

struct BlockListView: View {
    
    @EnvironmentObject var settingsVM: SettingsStore
        
    @State private var showingAlert = false
    @State private var blockThreemaID = ""
    
    let pubIncomingUpdate = NotificationCenter.default
        .publisher(for: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization))

    // MARK: - View

    var body: some View {
        List {
            Section {
                ForEach(settingsVM.blacklist.sorted(), id: \.self) { blockedID in
                    Text(blockedID)
                }
                .onDelete(perform: delete)
                if settingsVM.blacklist.isEmpty {
                    Text(#localize("settings_privacy_blocklist_emptylist"))
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(String.localizedStringWithFormat(
                    #localize("settings_privacy_blocklist_footer"),
                    TargetManager.localizedAppName
                ))
            }
        }
        .onReceive(pubIncomingUpdate) { _ in
            NotificationPresenterWrapper.shared.present(type: .settingsSyncSuccess)
        }
        .navigationTitle(#localize("settings_privacy_blocklist"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let color =
                    if #available(iOS 26.0, *) {
                        Color.primary
                    }
                    else {
                        Color.accentColor
                    }
                
                Button {
                    showingAlert.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .tint(color)
                .alert(
                    String.localizedStringWithFormat(
                        #localize("settings_privacy_blocklist_alert_add_description"),
                        TargetManager.localizedAppName
                    ), isPresented: $showingAlert
                ) {
                    TextField(
                        String.localizedStringWithFormat(
                            #localize("settings_privacy_blocklist_alert_threema_id"),
                            TargetManager.localizedAppName
                        ), text: $blockThreemaID
                    )
                    Button(#localize("add_button")) {
                        let blockID = blockThreemaID.uppercased()
                        blockThreemaID = ""
                        guard blockID.count == kIdentityLen else {
                            NotificationPresenterWrapper.shared.present(type: .idWrongLength)
                            return
                        }
                        
                        settingsVM.blacklist.insert(blockID)
                        NotificationPresenterWrapper.shared.present(type: .saveSuccess)
                    }
                    Button(#localize("cancel"), role: .cancel) { }
                }
            }
        }
    }
    
    private func delete(at offsets: IndexSet) {
        guard let firstOffset = offsets.first else {
            return
        }
        
        settingsVM.blacklist.remove(settingsVM.blacklist.sorted()[firstOffset])
    }
}

struct BlockListView_Previews: PreviewProvider {
    static var previews: some View {
        
        NavigationView {
            BlockListView()
        }
        .tint(.accentColor)
        .environmentObject(BusinessInjector.ui.settingsStore as! SettingsStore)
    }
}
