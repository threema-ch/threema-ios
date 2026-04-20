import SwiftUI
import ThreemaFramework
import ThreemaMacros

enum ContactListFilterItem: Int {
    case contacts = 0
    case groups = 1
    case distributionLists = 2
}

// MARK: - MenuItem

extension ContactListFilterItem: MenuItem {
    var id: Self { self }
    
    var label: String {
        switch self {
        case .contacts:
            #localize("segmentcontrol_contacts")
        case .groups:
            #localize("segmentcontrol_groups")
        case .distributionLists:
            #localize("segmentcontrol_distribution_list")
        }
    }
    
    var icon: ThreemaImageResource {
        switch self {
        case .contacts:
            .systemImage("person.2")
        case .groups:
            .systemImage("person.3")
        case .distributionLists:
            .systemImage("megaphone")
        }
    }
    
    var enabled: Bool {
        switch self {
        case .contacts, .groups:
            true
        case .distributionLists:
            ThreemaEnvironment.distributionListsActive
        }
    }
    
    var accessibilityLabel: String? {
        switch self {
        case .contacts:
            #localize("segmentcontrol_contacts")
        case .groups:
            #localize("segmentcontrol_groups")
        case .distributionLists:
            #localize("segmentcontrol_distribution_list")
        }
    }
}
