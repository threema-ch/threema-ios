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

import Foundation
import UIKit

final class SettingsCollectionView: UICollectionView, UICollectionViewDelegate {
    
    // MARK: - Properties

    private weak var coordinator: SettingsCoordinator?

    // MARK: - Lifecycle

    init(coordinator: SettingsCoordinator?) {
        self.coordinator = coordinator
        
        let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
            let config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        }
        
        super.init(frame: .zero, collectionViewLayout: layout)
        
        delegate = self
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Updates
    
    func updateSelection(for sizeClass: UIUserInterfaceSizeClass) {
        if sizeClass == .compact {
            indexPathsForSelectedItems?.forEach {
                deselectItem(at: $0, animated: false)
            }
        }
        else {
            guard let destination = coordinator?.currentDestination,
                  let dataSource = dataSource as? SettingsCollectionViewDataSource,
                  let row = SettingsCollectionViewDataSource.Row.row(for: destination),
                  let index = dataSource.indexPathForItem(row) else {
                return
            }

            selectItem(at: index, animated: false, scrollPosition: .centeredVertically)
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let dataSource = dataSource as? SettingsCollectionViewDataSource else {
            return false
        }
        
        return dataSource.canSelectItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let dataSource = dataSource as? SettingsCollectionViewDataSource else {
            return false
        }
        
        return dataSource.canSelectItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let dataSource = dataSource as? SettingsCollectionViewDataSource else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        
        dataSource.didSelectItem(at: indexPath)
    }
}
