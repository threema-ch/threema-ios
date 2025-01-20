//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
                Text(#localize("settings_privacy_blocklist_footer"))
            }
        }
        .onReceive(pubIncomingUpdate) { _ in
            NotificationPresenterWrapper.shared.present(type: .settingsSyncSuccess)
        }
        .navigationTitle(#localize("settings_privacy_blocklist"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAlert.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .tint(Color(.primary))
                .alert(#localize("settings_privacy_blocklist_alert_add_description"), isPresented: $showingAlert) {
                    TextField(#localize("settings_privacy_blocklist_alert_threema_id"), text: $blockThreemaID)
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
        .tint(UIColor.primary.color)
        .environmentObject(BusinessInjector().settingsStore as! SettingsStore)
    }
}
