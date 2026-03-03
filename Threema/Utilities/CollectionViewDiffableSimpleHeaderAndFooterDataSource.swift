//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

/// Simple subclass to provide easy header and footer `UICollectionReusableView` configuration
final class CollectionViewDiffableSimpleHeaderAndFooterDataSource<
    Section: Hashable,
    Row: Hashable
>: UICollectionViewDiffableDataSource<Section, Row> {
    typealias SupplementaryProvider = (UICollectionView, Section, IndexPath) -> UICollectionReusableView
    
    let headerProvider: SupplementaryProvider?
    let footerProvider: SupplementaryProvider?
    
    /// Create a new diffable data source
    /// - Parameters:
    ///   - collectionView: Collection view the data source will be attached to
    ///   - cellProvider: Cell provider for cells
    ///   - headerProvider: Called to ask for an optional header string
    ///   - footerProvider: Called to ask for an optional footer string
    init(
        collectionView: UICollectionView,
        cellProvider: @escaping UICollectionViewDiffableDataSource<Section, Row>.CellProvider,
        headerProvider: SupplementaryProvider? = nil,
        footerProvider: SupplementaryProvider? = nil
    ) {
        self.headerProvider = headerProvider
        self.footerProvider = footerProvider
        
        super.init(collectionView: collectionView, cellProvider: cellProvider)
    }
    
    @available(*, unavailable)
    override init(
        collectionView: UICollectionView,
        cellProvider: @escaping UICollectionViewDiffableDataSource<Section, Row>.CellProvider
    ) {
        fatalError("Not supported.")
    }
    
    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            guard let headerProvider else {
                fatalError("No header provider set")
            }
            let section = snapshot().sectionIdentifiers[indexPath.section]
            return headerProvider(collectionView, section, indexPath)
        }
        else {
            guard let footerProvider else {
                fatalError("No footer provider set.")
            }
            let section = snapshot().sectionIdentifiers[indexPath.section]
            return footerProvider(collectionView, section, indexPath)
        }
    }
}
