//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import DifferenceKit
import Foundation

protocol MentionsTableViewDelegate: AnyObject {
    func contactSelected(contact: MentionableIdentity)
    func hasMatches(for searchString: String) -> Bool
    func shouldHideMentionsTableView(_ hide: Bool)
}

class MentionsTableViewController: ThemedTableViewController {
    private var currMentions: [MentionableIdentity]
    private var allMentions: [MentionableIdentity]
    private var currSearchString = ""
    private weak var mentionsDelegate: MentionsTableViewDelegate?
    
    init(mentionsDelegate: MentionsTableViewDelegate, mentions: [MentionableIdentity]) {
        self.mentionsDelegate = mentionsDelegate
        self.currMentions = mentions
        self.allMentions = mentions
        
        super.init(style: .plain)
        
        view.backgroundColor = Colors.backgroundChatBar
    }
    
    private func updateMentions(_ mentions: [MentionableIdentity]) {
        let source = currMentions
        let target = mentions
        let changeSet = StagedChangeset(source: source, target: target)
        tableView.reload(using: changeSet, with: .automatic) { contacts in
            self.currMentions = contacts
        }
    }
    
    public func match(_ searchString: String) -> Bool {
        if searchString == "" {
            updateMentions(allMentions)
            return true
        }
        
        let filteredMentions = allMentions.filter { $0.corpus.contains(searchString.lowercased()) }
        currSearchString = searchString
        
        updateMentions(filteredMentions)
        
        return !filteredMentions.isEmpty
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currMentions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identity = currMentions[indexPath.row]
        
        let cell = MentionsTableViewCell(reuseIdentifier: identity.identity + currSearchString)
        
        cell.iconImageView.image = identity.contactImage
        cell.iconImageView.contentMode = .scaleAspectFill
        cell.nameLabel.text = identity.displayName
        
        cell.backgroundColor = Colors.backgroundChatBar
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        mentionsDelegate?.contactSelected(contact: currMentions[indexPath.row])
    }
}
