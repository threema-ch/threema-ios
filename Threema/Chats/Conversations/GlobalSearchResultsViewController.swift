//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaFramework

final class GlobalSearchResultsViewController: ThemedViewController {
    
    // MARK: - Structs
    
    struct GlobalSearchResult {
        var conversations: [Conversation]
        var baseMessages: [BaseMessage]
        
        func hasSearchResult() -> Bool {
            !conversations.isEmpty || !baseMessages.isEmpty
        }
    }
    
    // MARK: - Public properties
    
    var searchResults = GlobalSearchResult(conversations: [], baseMessages: []) {
        didSet {
            var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
            if !searchResults.conversations.isEmpty {
                snapshot.appendSections([.conversations])
                snapshot.appendItems(searchResults.conversations, toSection: .conversations)
            }
            if !searchResults.baseMessages.isEmpty {
                snapshot.appendSections([.baseMessages])
                snapshot.appendItems(searchResults.baseMessages, toSection: .baseMessages)
            }
            
            dataSource.apply(snapshot, animatingDifferences: true)
            emptyContentStackView.isHidden = searchResults.hasSearchResult()
        }
    }

    // MARK: - Private properties
    
    private static let conversationTableViewCellIdentifier = "ConversationTableViewCell"
    private static let baseMessageTableViewCellIdentifier = "BaseMessageTableViewCell"
        
    private let entityManager: EntityManager
    
    private lazy var emptyContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyContentStackView)
        view.isUserInteractionEnabled = false
        
        NSLayoutConstraint.activate([
            emptyContentStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyContentStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }()
    
    /// Empty content stack with a image and a label
    private lazy var emptyContentStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            emptyContentImage,
            emptyContentLabel,
        ])
        
        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        stack.spacing = 12
        stack.isHidden = true
        return stack
    }()
    
    // Empty content label
    private lazy var emptyContentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        
        label.text = "chat_search_no_matches".localized
        return label
    }()
    
    // Empty content image
    private lazy var emptyContentImage: UIImageView = {
        let image = UIImage(
            systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .subheadline)
        )
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = Colors.text
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 30.0),
            imageView.heightAnchor.constraint(equalToConstant: 30.0),
        ])

        return imageView
    }()
    
    /// The table view set as first sub view
    private lazy var tableView: UITableView = {
        // .grouped so the footer appears after the last search result
        // instead of floating above the results
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.keyboardDismissMode = .onDrag

        tableView.backgroundColor = Colors.plainBackgroundTableView
        
        return tableView
    }()
    
    private lazy var dataSource: TableViewDiffableSimpleHeaderAndFooterDataSource<Section, AnyHashable> = {
        let dataSource = TableViewDiffableSimpleHeaderAndFooterDataSource<
            Section,
            AnyHashable
        >(tableView: tableView) { [weak self] tableView, indexPath, item in
            
            switch item {
            case let conversation as Conversation:
                let conversationCell: ConversationTableViewCell = tableView.dequeueCell(for: indexPath)
                conversationCell.setConversation(to: conversation)
                conversationCell.setNavigationController(to: self?.navigationController)
                // use clear color as background, because we use a grouped table view
                conversationCell.backgroundColor = .clear
                return conversationCell
            case let baseMessage as BaseMessage:
                let searchResultsCell: GlobalSearchResultsTableViewCell = tableView.dequeueCell(for: indexPath)
                searchResultsCell.message = baseMessage
                // use clear color as background, because we use a grouped table view
                searchResultsCell.backgroundColor = .clear
                return searchResultsCell
            default:
                return UITableViewCell()
            }
        } headerProvider: { _, section in
            switch section {
            case .conversations:
                return "chats_title".localized
            case .baseMessages:
                return "messages".localized
            }
        }
        
        dataSource.defaultRowAnimation = .fade
        return dataSource
    }()
    
    private enum Section: Hashable {
        case conversations
        case baseMessages
    }
    
    // MARK: - Lifecycle
    
    /// Create a new chat search results controller
    /// - Parameter entityManager: Entity manager used to fetch messages shown in search results
    init(
        entityManager: EntityManager
    ) {
        self.entityManager = entityManager
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("No available")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addObservers()
        configureTableView()
        configureViews()
    }
    
    // MARK: - Configuration
        
    private func configureTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = dataSource
                
        tableView.registerCell(GlobalSearchResultsTableViewCell.self)
        tableView.registerCell(ConversationTableViewCell.self)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    /// Configure the empty content stack view
    private func configureViews() {
        view.addSubview(emptyContentView)
        NSLayoutConstraint.activate([
            emptyContentView.topAnchor.constraint(equalTo: tableView.topAnchor),
            emptyContentView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            emptyContentView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            emptyContentView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
        ])
    }
    
    /// Add observers for color theme changed
    private func addObservers() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name(kNotificationColorThemeChanged),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let weakSelf = self else {
                return
            }
            weakSelf.updateColors()
            
            weakSelf.tableView.backgroundColor = Colors.plainBackgroundTableView
            weakSelf.emptyContentImage.tintColor = Colors.text

            for cell in weakSelf.tableView.visibleCells {
                if let globalSearchResultsTableViewCell = cell as? GlobalSearchResultsTableViewCell {
                    globalSearchResultsTableViewCell.updateColors()
                }
                else if let conversationTableViewCell = cell as? ConversationTableViewCell {
                    conversationTableViewCell.updateColors()
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate

extension GlobalSearchResultsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        
        if let conversation = dataSource.itemIdentifier(for: indexPath) as? Conversation {
            let info: Dictionary = [kKeyConversation: conversation]
            NotificationCenter.default.post(
                name: NSNotification.Name(kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
        if let baseMessage = dataSource.itemIdentifier(for: indexPath) as? BaseMessage {
            let info: Dictionary = [kKeyConversation: baseMessage.conversation, kKeyMessage: baseMessage]
            NotificationCenter.default.post(
                name: NSNotification.Name(kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
    }
}
