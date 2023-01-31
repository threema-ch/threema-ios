//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import UIKit

// MARK: - Cells

public extension UITableView {

    /// Dequeue a new table view cell at the provided index path for the type provided
    ///
    /// - Parameter indexPath: Index path of cell
    /// - Returns: Cell of type `CellType`
    func dequeueCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType where CellType: Reusable {
        let cell = dequeueReusableCell(withIdentifier: CellType.reuseIdentifier, for: indexPath)
        
        guard let castedCell = cell as? CellType else {
            fatalError("Unable to cast reuse cell with identifier \(CellType.reuseIdentifier) to \(CellType.self)")
        }
        
        return castedCell
    }
    
    /// Register a new table view cell for reuse
    ///
    /// - Parameter : Table view cell conforming to `Reusable`
    func registerCell<CellType: UITableViewCell>(_: CellType.Type) where CellType: Reusable {
        register(CellType.self, forCellReuseIdentifier: CellType.reuseIdentifier)
    }
}

// MARK: - Header and footer

public extension UITableView {
    
    /// Dequeue a new header footer view
    ///
    /// - Returns: Header footer view of type `HeaderFooterViewType` if dequeueing and casting was successful
    func dequeueHeaderFooter<HeaderFooterViewType: UITableViewHeaderFooterView>()
        -> HeaderFooterViewType? where HeaderFooterViewType: Reusable {
        
        dequeueReusableHeaderFooterView(withIdentifier: HeaderFooterViewType.reuseIdentifier)
            as? HeaderFooterViewType
    }
    
    /// Register a new header footer view for reuse
    ///
    /// - Parameter :  Header footer view conforming to `Reusable`
    func registerHeaderFooter<HeaderFooterViewType: UITableViewHeaderFooterView>(_: HeaderFooterViewType.Type)
        where HeaderFooterViewType: Reusable {
        register(HeaderFooterViewType.self, forHeaderFooterViewReuseIdentifier: HeaderFooterViewType.reuseIdentifier)
    }
}
