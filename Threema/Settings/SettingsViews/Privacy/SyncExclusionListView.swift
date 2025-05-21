//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

struct SyncExclusionListView: View {
    
    @EnvironmentObject var settingsVM: SettingsStore
        
    @State private var showingAlert = false
    @State private var excludeThreemaID = ""
    
    let pubIncomingUpdate = NotificationCenter.default
        .publisher(for: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization))

    // MARK: - View

    var body: some View {
        List {
            Section {
                ForEach(settingsVM.syncExclusionList, id: \.self) { excludedID in
                    Text(excludedID)
                }
                .onDelete(perform: delete)
                if settingsVM.syncExclusionList.isEmpty {
                    Text(#localize("settings_privacy_syncexclusionlist_emptylist"))
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(String.localizedStringWithFormat(
                    #localize("settings_privacy_syncexclusionlist_footer"),
                    TargetManager.localizedAppName
                ))
            }
        }
        .onReceive(pubIncomingUpdate) { _ in
            NotificationPresenterWrapper.shared.present(type: .settingsSyncSuccess)
        }
        .navigationTitle(#localize("settings_privacy_exclusion_list"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAlert.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .tint(.accentColor)
                .alert(
                    String
                        .localizedStringWithFormat(
                            #localize("enter_id_to_exclude"),
                            TargetManager.localizedAppName
                        ),
                    isPresented: $showingAlert
                ) {
                    TextField(
                        String
                            .localizedStringWithFormat(
                                #localize("settings_privacy_syncexclusionlist_alert_threema_id"),
                                TargetManager.localizedAppName
                            ),
                        text: $excludeThreemaID
                    )
                    Button(#localize("add_button")) {
                        let excludeID = excludeThreemaID.uppercased()
                        excludeThreemaID = ""
                        guard excludeID.count == kIdentityLen else {
                            NotificationPresenterWrapper.shared.present(type: .idWrongLength)
                            return
                        }
                        
                        settingsVM.syncExclusionList.append(excludeID)
                        NotificationPresenterWrapper.shared.present(type: .saveSuccess)
                    }
                    Button(#localize("cancel"), role: .cancel) { }
                }
            }
        }
    }
    
    private func delete(at offsets: IndexSet) {
        settingsVM.syncExclusionList.remove(atOffsets: offsets)
    }
}

struct ExclusionListView_Previews: PreviewProvider {
    static var previews: some View {
        
        NavigationView {
            SyncExclusionListView()
        }
        .tint(.accentColor)
        .environmentObject(BusinessInjector.ui.settingsStore as! SettingsStore)
    }
}
