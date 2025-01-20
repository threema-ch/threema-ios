//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import ThreemaMacros
import UIKit

/// Show a simple list of all the provided groups
final class GroupsTableViewController: ThemedTableViewController {
    
    private let groups: [Group]
    
    /// Create a new instance showing `groups` in the provided order
    /// - Parameter groups: Groups to show
    init(groups: [Group]) {
        self.groups = groups
        
        super.init(style: .plain)
    }
    
    @available(*, unavailable)
    override init(style: UITableView.Style) {
        fatalError("init(style:) has not been implemented")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = #localize("groups")
                
        tableView.registerCell(GroupCell.self)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let groupCell: GroupCell = tableView.dequeueCell(for: indexPath)
        groupCell.size = .medium
        groupCell.group = groups[indexPath.row]
        groupCell.accessoryType = .disclosureIndicator
        return groupCell
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        // no-op: Do not override cell color
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let group = groups[indexPath.row]
        
        let groupDetailsViewController = GroupDetailsViewController(for: group)
        show(groupDetailsViewController, sender: self)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
