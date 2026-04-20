import Foundation

public protocol MentionsTableViewDelegate: AnyObject {
    func contactSelected(contact: MentionableIdentity)
    func hasMatches(for searchString: String) -> Bool
    func shouldHideMentionsTableView(_ hide: Bool)
}

public final class MentionsTableViewController: ThemedViewController {

    private enum Section: Hashable {
        case main
    }
    
    private var currentMentions: [MentionableIdentity]
    private var allMentions: [MentionableIdentity]
    private var currentSearchString = ""
    private weak var mentionsDelegate: MentionsTableViewDelegate?
    
    /// The table view set as root view
    public lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return tableView
    }()
    
    private lazy var dataSource = UITableViewDiffableDataSource<
        Section,
        MentionableIdentity
    >(tableView: tableView) { tableView, indexPath, identity in
        let cell: MentionsTableViewCell = tableView.dequeueCell(for: indexPath)
        let entityManager = BusinessInjector.ui.entityManager
        entityManager.performAndWait {
            if let contactEntity = entityManager.entityFetcher.contactEntity(for: identity.identity) {
                cell.profilePictureView.info = .contact(Contact(contactEntity: contactEntity))
            }
            else {
                cell.profilePictureView.info = .group(nil)
            }
        }
        
        cell.nameLabel.text = identity.displayName
                
        return cell
    }
    
    // MARK: - Lifecycle
    
    public init(mentionsDelegate: MentionsTableViewDelegate, mentions: [MentionableIdentity]) {
        self.mentionsDelegate = mentionsDelegate
        self.currentMentions = mentions
        self.allMentions = mentions
        
        super.init(nibName: nil, bundle: nil)
        
        if #available(iOS 26.0, *) {
            view.backgroundColor = nil
            tableView.backgroundColor = nil
            
            // "Hide" last cell divider
            tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 1))
        }
        else {
            view.backgroundColor = .systemGroupedBackground
        }
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("No available")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadView() {
        // DON'T call super
        view = tableView
    }
    
    override public func viewDidLoad() {
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
            self.currentMentions = mentions
        }
    }
    
    public func match(_ searchString: String) -> Bool {
        if searchString == "" {
            updateMentions(allMentions)
            return true
        }
        
        let filteredMentions = allMentions.filter { $0.corpus.contains(searchString.lowercased()) }
        currentSearchString = searchString
        
        updateMentions(filteredMentions)
        
        return !filteredMentions.isEmpty
    }
    
    override public func updateColors() {
        // Do not call super after iOS 26
        if #unavailable(iOS 26.0) {
            super.updateColors()
        }
    }
}

// MARK: - UITableViewDelegate

extension MentionsTableViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        mentionsDelegate?.contactSelected(contact: currentMentions[indexPath.row])
    }
}
