import CocoaLumberjackSwift
import UIKit

/// Show a list with with all member of the provided group
final class GroupMembersTableViewController: ThemedTableViewController {
    
    private let groupDetailsDataSource: GroupDetailsDataSource
    
    private var rows = [GroupDetails.Row]()
    
    init(groupDetailsDataSource: GroupDetailsDataSource) {
        self.groupDetailsDataSource = groupDetailsDataSource
        
        super.init(style: .plain)
        
        reloadRows()
        
        // TODO: Register observer
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
        
        navigationItem.title = groupDetailsDataSource.membersTitleSummary
        
        tableView.registerCell(ContactCell.self)
        tableView.registerCell(MembersActionDetailsTableViewCell.self)
    }
    
    deinit {
        DDLogDebug("\(#function)")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let row = rows[indexPath.row]
        
        var cell: UITableViewCell
        
        switch row {
        
        case let .meCreator(left, inMembers: _):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .me
            contactCell.contentView.alpha = left ? GroupDetailsDataSource.Configuration.leftAlpha : 1
            cell = contactCell
            
        case let .contactCreator(contact, left: left, inMembers: _):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .contact(contact)
            contactCell.contentView.alpha = left ? GroupDetailsDataSource.Configuration.leftAlpha : 1
            cell = contactCell
            
        case .unknownContactCreator(_, inMembers: _):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .unknownContact
            // No alpha change as an unknown contact is always shown dimmed
            cell = contactCell
        
        case .meContact:
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .me
            cell = contactCell
        
        case let .contact(contact, isSelfMember: isSelfMember):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .contact(contact)
            contactCell.contentView.alpha = !isSelfMember ? GroupDetailsDataSource.Configuration.leftAlpha : 1
            cell = contactCell
            
        case .unknownContact:
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .unknownContact
            cell = contactCell
            
        case let .membersAction(action):
            let actionCell: MembersActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            actionCell.action = action
            cell = actionCell
            
        default:
            fatalError("Not supported cell type \(type(of: row))")
        }
        
        return cell
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        // no-op: Do not override cell color
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows[indexPath.row]
        
        switch row {
        
        case let .membersAction(action):
            guard let cell = tableView.cellForRow(at: indexPath) else {
                fatalError("We should have a cell that was tapped for an action.")
            }
            
            action.run(cell)
            
        case let .contactCreator(contact, left: _, inMembers: _),
             let .contact(contact, _):
            let singleDetailsViewController = SingleDetailsViewController(for: contact)
            show(singleDetailsViewController, sender: self)
            
        default:
            // No action possible
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Update
    
    private func reloadRows() {
        rows = groupDetailsDataSource.groupMembers(limited: false)
        tableView.reloadData()
    }
}
