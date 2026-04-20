import UIKit

// MARK: - Cells

extension UICollectionView {

    /// Dequeue a new collection view cell at the provided index path for the type provided
    ///
    /// - Parameter indexPath: Index path of cell
    /// - Returns: Cell of type `CellType`
    public func dequeueCell<CellType: UICollectionViewCell>(for indexPath: IndexPath) -> CellType
        where CellType: Reusable {
        let cell = dequeueReusableCell(withReuseIdentifier: CellType.reuseIdentifier, for: indexPath)
        
        guard let castedCell = cell as? CellType else {
            fatalError("Unable to cast reuse cell with identifier \(CellType.reuseIdentifier) to \(CellType.self)")
        }
        
        return castedCell
    }
    
    /// Register a new collection view cell for reuse
    ///
    /// - Parameter : Collection view cell conforming to `Reusable`
    public func registerCell<CellType: UICollectionViewCell>(_: CellType.Type) where CellType: Reusable {
        register(CellType.self, forCellWithReuseIdentifier: CellType.reuseIdentifier)
    }
}
