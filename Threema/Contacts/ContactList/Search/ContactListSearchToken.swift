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

import Foundation
import ThreemaMacros

protocol ContactListTokenProtocol: Equatable, Sendable {
    var title: String { get }
    var icon: UIImage? { get }
}

extension ContactListTokenProtocol {
    public var searchToken: UISearchToken {
        let token = UISearchToken(icon: icon, text: title)
        token.representedObject = self
        return token
    }
}

public enum ContactListSearchToken: ContactListTokenProtocol, Identifiable, Hashable {
    
    public struct DirectoryTokenInfo: Identifiable, Equatable, Hashable, Sendable {
        public let id: String
        public let title: String
    }
    
    case contacts
    case groups
    case distributionLists
    case directoryContacts
    case directoryFilterToken(info: DirectoryTokenInfo)
    
    // Tokens available for the current build flavor
    public static var availableTokens: [ContactListSearchToken] {
        switch TargetManager.current {
        case .threema, .green:
            if ThreemaEnvironment.distributionListsActive {
                [.contacts, .groups, .distributionLists]
            }
            else {
                [.contacts, .groups]
            }
            
        case .work, .blue, .onPrem, .customOnPrem:
            if ThreemaEnvironment.distributionListsActive {
                if BusinessInjector.ui.userSettings.companyDirectory {
                    [.contacts, .groups, .distributionLists, .directoryContacts]
                }
                else {
                    [.contacts, .groups, .distributionLists]
                }
            }
            else {
                if BusinessInjector.ui.userSettings.companyDirectory {
                    [.contacts, .groups, .directoryContacts]
                }
                else {
                    [.contacts, .groups]
                }
            }
        }
    }
    
    public var id: String {
        title
    }
    
    public var title: String {
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
    
    public var icon: UIImage? {
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
    
    public var contentConfiguration: UIListContentConfiguration {
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
