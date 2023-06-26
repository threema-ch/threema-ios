//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import Foundation
import ThreemaFramework

class MentionableIdentity: Hashable {
    enum ContactKind: Hashable {
        case all
        case contact(String)
    }
    
    var contactKind: ContactKind
    var entityFetcher: EntityFetcher
    
    lazy var corpus: String = {
        switch contactKind {
        case .all: return BundleUtil.localizedString(forKey: "all").lowercased()
        case let ContactKind.contact(identity):
            guard let contact = entityFetcher.contact(for: identity) else {
                DDLogError("Created MentionableIdentity for a contact that doesn't exist")
                return ""
            }
            return "\(contact.displayName.lowercased()) \((contact.publicNickname ?? "").lowercased())"
        }
    }()
    
    lazy var contactImage: UIImage? = {
        switch contactKind {
        case .all: return AvatarMaker.shared().unknownPersonImage()
        case let ContactKind.contact(identity):
            guard let contact = entityFetcher.contact(for: identity) else {
                DDLogError("Created MentionableIdentity for a contact that doesn't exist")
                return UIImage()
            }
            return AvatarMaker().avatar(for: contact, size: 35, masked: true)
        }
    }()
    
    lazy var displayName: String = {
        switch contactKind {
        case .all: return BundleUtil.localizedString(forKey: "all")
        case let ContactKind.contact(identity):
            guard let contact = entityFetcher.contact(for: identity) else {
                DDLogError("Created MentionableIdentity for a contact that doesn't exist")
                return ""
            }
            return "\(contact.displayName)"
        }
    }()
    
    lazy var identity: String = {
        switch contactKind {
        case .all: return ""
        case let ContactKind.contact(identity):
            return identity
        }
    }()
    
    lazy var mentionIdentity: String = {
        switch contactKind {
        case .all: return "@@@@@@@@"
        case let ContactKind.contact(identity):
            return identity
        }
    }()
    
    init(identity: String? = nil, entityFetcher: EntityFetcher = EntityManager().entityFetcher) {
        if let identity {
            self.contactKind = .contact(identity)
        }
        else {
            self.contactKind = .all
        }
        self.entityFetcher = entityFetcher
    }
    
    static func == (lhs: MentionableIdentity, rhs: MentionableIdentity) -> Bool {
        lhs.contactKind == rhs.contactKind
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(contactKind)
    }
}
