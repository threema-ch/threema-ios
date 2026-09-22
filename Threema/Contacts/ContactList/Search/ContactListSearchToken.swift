import Foundation
import ThreemaMacros

protocol ContactListTokenProtocol: Equatable, Sendable {
    var title: String { get }
    var icon: UIImage? { get }
}

extension ContactListTokenProtocol {
    var searchToken: UISearchToken {
        let token = UISearchToken(icon: icon, text: title)
        token.representedObject = self
        return token
    }
}

enum ContactListSearchToken: ContactListTokenProtocol, Identifiable, Hashable {
    
    struct DirectoryTokenInfo: Identifiable, Equatable, Hashable, Sendable {
        let id: String
        let title: String
    }
    
    case contacts
    case groups
    case distributionLists
    case directoryContacts
    case directoryFilterToken(info: DirectoryTokenInfo)
    
    // Tokens available for the current build flavor
    static var availableTokens: [ContactListSearchToken] {
        switch TargetManager.current {
        case .threema, .green:
            if ThreemaEnvironment.distributionListsActive {
                return [.contacts, .groups, .distributionLists]
            }
            else {
                return [.contacts, .groups]
            }
            
        case .work, .blue, .onPrem, .customOnPrem:
            guard !RemoteSecretProvider.isRemoteSecretEnabled else {
                if BusinessInjector.ui.userSettings.companyDirectory {
                    return [.contacts, .directoryContacts]
                }
                else {
                    return [.contacts]
                }
            }
            if ThreemaEnvironment.distributionListsActive {
                if BusinessInjector.ui.userSettings.companyDirectory {
                    return [.contacts, .groups, .distributionLists, .directoryContacts]
                }
                else {
                    return [.contacts, .groups, .distributionLists]
                }
            }
            else {
                if BusinessInjector.ui.userSettings.companyDirectory {
                    return [.contacts, .groups, .directoryContacts]
                }
                else {
                    return [.contacts, .groups]
                }
            }
        }
    }
    
    var id: String {
        title
    }
    
    var title: String {
        switch self {
        case .contacts:
            #localize("contact_list_search_token_title_contacts")
        case .groups:
            #localize("contact_list_search_token_title_groups")
        case .distributionLists:
            #localize("contact_list_search_token_title_distribution_lists")
        case .directoryContacts:
            String.localizedStringWithFormat(
                #localize("contact_list_search_token_title_directory_contacts"),
                BusinessInjector.ui.myIdentityStore.companyName ?? ""
            )
        case let .directoryFilterToken(info: info):
            info.title
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .contacts:
            UIImage(systemName: "person")
        case .groups:
            UIImage(systemName: "person.3")
        case .distributionLists:
            UIImage(systemName: "megaphone")
        case .directoryContacts:
            UIImage(systemName: "building.2")
        case .directoryFilterToken:
            UIImage(systemName: "tag")
        }
    }
    
    var contentConfiguration: UIListContentConfiguration {
        var content = UIListContentConfiguration.cell()
        content.text = title
        content.image = icon
        
        let mediumScaleSymbolConfiguration = UIImage.SymbolConfiguration(scale: .medium)
        let mediumWeightSymbolConfiguration = UIImage.SymbolConfiguration(weight: .medium)
        content.imageProperties.preferredSymbolConfiguration = mediumScaleSymbolConfiguration.applying(
            mediumWeightSymbolConfiguration
        )
        
        return content
    }
}
