//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

protocol MentionsTableViewDelegate: AnyObject {
    func contactSelected(contact: MentionableIdentity)
    func hasMatches(for searchString: String) -> Bool
    func shouldHideMentionsTableView(_ hide: Bool)
}

class MentionsTableViewController: ThemedViewController {
    
    private enum Section: Hashable {
        case main
    }
    
    private var currMentions: [MentionableIdentity]
    private var allMentions: [MentionableIdentity]
    private var currSearchString = ""
    private weak var mentionsDelegate: MentionsTableViewDelegate?
    
    /// The table view set as root view
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return tableView
    }()
    
    private lazy var dataSource = UITableViewDiffableDataSource<
        Section,
        MentionableIdentity
    >(tableView: tableView) { tableView, indexPath, identity in
        let cell: MentionsTableViewCell = tableView.dequeueCell(for: indexPath)
        let entityManager = EntityManager()
        entityManager.performAndWait {
            if let contactEntity = entityManager.entityFetcher.contact(for: identity.identity) {
                cell.profilePictureView.info = .contact(Contact(contactEntity: contactEntity))
            }
            else {
                cell.profilePictureView.info = .group(nil)
            }
        }
        
        cell.nameLabel.text = identity.displayName
        
        cell.backgroundColor = Colors.backgroundChatBar
        
        return cell
    }
    
    // MARK: - Lifecycle
    
    init(mentionsDelegate: MentionsTableViewDelegate, mentions: [MentionableIdentity]) {
        self.mentionsDelegate = mentionsDelegate
        self.currMentions = mentions
        self.allMentions = mentions
        
        super.init(nibName: nil, bundle: nil)
        
        view.backgroundColor = Colors.backgroundChatBar
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("No available")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // DON'T call super
        view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        updateMentions(allMentions)
    }
    
    // MARK: - Configuration
    
    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = dataSource
        
        tableView.registerCell(MentionsTableViewCell.self)
    }
    
    // MARK: - Updates
    
    private func updateMentions(_ mentions: [MentionableIdentity]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, MentionableIdentity>()
        snapshot.appendSections([.main])
        snapshot.appendItems(mentions)
        
        dataSource.apply(snapshot) {
            self.currMentions = mentions
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
}

// MARK: - UITableViewDelegate

extension MentionsTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        mentionsDelegate?.contactSelected(contact: currMentions[indexPath.row])
    }
}
