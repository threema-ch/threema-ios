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

import Foundation
import ThreemaMacros

public enum GlobalSearchConversationScope: Int {
    case all
    case oneToOne
    case groups
    case archived
    
    public var title: String {
        switch self {
        case .all:
            #localize("all")
        case .oneToOne:
            #localize("one_to_one_chat")
        case .groups:
            #localize("groups")
        case .archived:
            #localize("archived_title")
        }
    }
}

public enum GlobalSearchMessageToken: Identifiable, CaseIterable {
    // Message markers
    case star
    
    // Message types
    case text
    case caption
    case poll
    case location
    
    public var id: Self {
        self
    }
    
    public var title: String {
        switch self {
        case .star:
            #localize("conversations_global_search_token_starred")
            
        case .text:
            #localize("conversations_global_search_token_text")
            
        case .caption:
            #localize("conversations_global_search_token_captions")
            
        case .poll:
            #localize("conversations_global_search_token_polls")
            
        case .location:
            #localize("conversations_global_search_token_locations")
        }
    }
    
    public var icon: UIImage? {
        switch self {
        case .star:
            UIImage(systemName: "star")
            
        case .text:
            UIImage(systemName: "text.alignleft")
            
        case .caption:
            UIImage(systemName: "text.below.photo")

        case .poll:
            UIImage(systemName: "chart.pie")

        case .location:
            UIImage(systemName: "mappin.and.ellipse")
        }
    }
    
    public var searchToken: UISearchToken {
        let token = UISearchToken(icon: icon, text: title)
        token.representedObject = self
        return token
    }
}
