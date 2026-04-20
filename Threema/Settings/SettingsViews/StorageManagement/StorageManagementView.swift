import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct StorageManagementView: View {
    @StateObject var model: Model

    var body: some View {
        List {
            StorageSection()
            ManageAllDataSection()
            AllConversationSection()
        }
        .navigationBarTitle(
            #localize("storage_management"),
            displayMode: .inline
        )
        .listStyle(InsetGroupedListStyle())
        .environmentObject(model)
    }
}
