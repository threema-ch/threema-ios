import UIKit

// MARK: - Cells

extension UITableView {

    /// Dequeue a new table view cell at the provided index path for the type provided
    ///
    /// - Parameter indexPath: Index path of cell
    /// - Returns: Cell of type `CellType`
    public func dequeueCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType where CellType: Reusable {
        let cell = dequeueReusableCell(withIdentifier: CellType.reuseIdentifier, for: indexPath)
        
        guard let castedCell = cell as? CellType else {
            fatalError("Unable to cast reuse cell with identifier \(CellType.reuseIdentifier) to \(CellType.self)")
        }
        
        return castedCell
    }
    
    /// Register a new table view cell for reuse
    ///
    /// - Parameter : Table view cell conforming to `Reusable`
    public func registerCell<CellType: UITableViewCell>(_: CellType.Type) where CellType: Reusable {
        register(CellType.self, forCellReuseIdentifier: CellType.reuseIdentifier)
    }
}

// MARK: - Header and footer

extension UITableView {
    
    /// Dequeue a new header footer view
    ///
    /// - Returns: Header footer view of type `HeaderFooterViewType` if dequeueing and casting was successful
    public func dequeueHeaderFooter<HeaderFooterViewType: UITableViewHeaderFooterView>()
        -> HeaderFooterViewType? where HeaderFooterViewType: Reusable {
        
        dequeueReusableHeaderFooterView(withIdentifier: HeaderFooterViewType.reuseIdentifier)
            as? HeaderFooterViewType
    }
    
    /// Register a new header footer view for reuse
    ///
    /// - Parameter :  Header footer view conforming to `Reusable`
    public func registerHeaderFooter<HeaderFooterViewType: UITableViewHeaderFooterView>(_: HeaderFooterViewType.Type)
        where HeaderFooterViewType: Reusable {
        register(HeaderFooterViewType.self, forHeaderFooterViewReuseIdentifier: HeaderFooterViewType.reuseIdentifier)
    }
}
