import Foundation
import ThreemaFramework
import ThreemaMacros

enum ContactListAddItem: MenuItem {
    case contacts
    case groups
    case distributionLists

    var id: Self { self }
    
    var label: String {
        switch self {
        case .contacts:
            #localize("contactList_add_contact")
        case .groups:
            #localize("contactList_add_group")
        case .distributionLists:
            #localize("distribution_list_create")
        }
    }
    
    var icon: ThreemaImageResource {
        switch self {
        case .contacts:
            .systemImage("person.badge.plus")
        case .groups:
            .bundleImage("threema.person.3.badge.plus")
        case .distributionLists:
            .bundleImage("threema.megaphone.badge.plus")
        }
    }
    
    var enabled: Bool {
        let mdm = MDMSetup()
        return switch self {
        case .contacts:
            !(mdm?.disableAddContact() ?? true)
        case .groups:
            !(mdm?.disableCreateGroup() ?? false)
        case .distributionLists:
            ThreemaEnvironment.distributionListsActive
        }
    }
    
    var accessibilityLabel: String? {
        nil
    }
}
