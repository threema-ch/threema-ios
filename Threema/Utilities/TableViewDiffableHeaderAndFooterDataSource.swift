import UIKit

/// Simple subclass to provide easy header and footer string configuration
final class TableViewDiffableSimpleHeaderAndFooterDataSource<
    Section: Hashable,
    Row: Hashable
>: UITableViewDiffableDataSource<Section, Row> {
    typealias SupplementaryProvider = (UITableView, Section) -> String?
    
    let headerProvider: SupplementaryProvider?
    let footerProvider: SupplementaryProvider?
    
    /// Create a new diffable data source
    /// - Parameters:
    ///   - tableView: Table view the data source will be attached to
    ///   - cellProvider: Cell provider for cells
    ///   - headerProvider: Called to ask for an optional header string
    ///   - footerProvider: Called to ask for an optional footer string
    init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider,
        headerProvider: SupplementaryProvider? = nil,
        footerProvider: SupplementaryProvider? = nil
    ) {
        self.headerProvider = headerProvider
        self.footerProvider = footerProvider
        
        super.init(tableView: tableView, cellProvider: cellProvider)
    }
    
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider
    ) {
        fatalError("Not supported.")
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = snapshot().sectionIdentifiers[section]
        return headerProvider?(tableView, section)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let section = snapshot().sectionIdentifiers[section]
        return footerProvider?(tableView, section)
    }
}
