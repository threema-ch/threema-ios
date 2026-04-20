import UIKit

public final class RecipientSearchResultsViewController: ThemedViewController {

    // MARK: - Private types

    private typealias Section = RecipientSearchResultsViewModel.Section
    private typealias DataSource = UITableViewDiffableDataSource<Section, ItemID>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<Section, ItemID>

    // MARK: - Internal properties

    let model: RecipientSearchResultsViewModel

    // MARK: - Private properties

    private lazy var dataSource = DataSource(tableView: tableView, cellProvider: cellProvider)

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tableHeaderView = UIView(frame: .zero)
        view.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 4))
        view.sectionHeaderTopPadding = 0.0

        view.registerCell(ContactCell.self)
        view.registerCell(GroupCell.self)
        view.registerCell(DistributionListCell.self)
        view.registerHeaderFooter(DetailsSectionHeaderView.self)

        view.delegate = self
        view.allowsMultipleSelection = true

        return view
    }()

    // MARK: - Lifecycle

    public init(model: RecipientSearchResultsViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Super class overrides

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        observeModelUpdates()
    }

    override public func updateColors() {
        view.backgroundColor = Colors.backgroundGroupedViewController
    }

    // MARK: - Private Methods

    private func setupViews() {
        view.addSubview(tableView)
        
        setupTableView()
    }

    private func setupTableView() {
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    private func observeModelUpdates() {
        withObservationTracking {
            _ = model.searchResultItemIdentifiers
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateSnapshot()
                self?.observeModelUpdates()
            }
        }
    }

    private func cellProvider(
        _ tableView: UITableView,
        _ indexPath: IndexPath,
        _ itemIdentifier: ItemID
    ) -> UITableViewCell? {
        guard let selectableItem = model.selectableItem(for: itemIdentifier) else {
            return nil
        }

        switch selectableItem.item {
        case let .contact(contact):
            let cell: ContactCell = tableView.dequeueCell(for: indexPath)
            cell.content = .contact(contact)
            cell.selectionStyle = .none
            cell.hasCheckmark = true
            cell.setSelected(selectableItem.isSelected, animated: false)

            return cell

        case let .group(group):
            let cell: GroupCell = tableView.dequeueCell(for: indexPath)
            cell.group = group
            cell.selectionStyle = .none
            cell.hasCheckmark = true
            cell.setSelected(selectableItem.isSelected, animated: false)

            return cell

        case let .distributionList(list):
            let cell: DistributionListCell = tableView.dequeueCell(for: indexPath)
            cell.distributionList = list
            cell.selectionStyle = .none
            cell.hasCheckmark = true
            cell.setSelected(selectableItem.isSelected, animated: false)

            return cell
        }
    }

    private func updateSnapshot() {
        var snapshot = DataSourceSnapshot()
        for section in Section.allCases {
            let items = model.items(for: section)
            if !items.isEmpty {
                snapshot.appendSections([section])
                snapshot.appendItems(items)
            }
        }
        snapshot.reconfigureItems(model.changedItemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UITableViewDelegate

extension RecipientSearchResultsViewController: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let identifier = dataSource.itemIdentifier(for: indexPath) {
            model.selectItem(with: identifier)
        }
    }

    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let identifier = dataSource.itemIdentifier(for: indexPath) {
            model.deselectItem(with: identifier)
        }
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = dataSource.sectionIdentifier(for: section),
              model.items(for: section).isEmpty == false,
              let headerView: DetailsSectionHeaderView = tableView.dequeueHeaderFooter() else {
            return nil
        }

        headerView.title = section.title
        return headerView
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        let shouldBeSelected = model.isIdentifierSelected(identifier)
        let isCurrentlySelected = tableView.indexPathsForSelectedRows?.contains(indexPath) ?? false

        // Only update if state doesn't match
        if shouldBeSelected, !isCurrentlySelected {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
        else if !shouldBeSelected, isCurrentlySelected {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        else {
            // No-op
        }
    }
}
