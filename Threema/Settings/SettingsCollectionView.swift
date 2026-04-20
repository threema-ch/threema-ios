import Foundation
import UIKit

final class SettingsCollectionView: UICollectionView, UICollectionViewDelegate {
    
    // MARK: - Properties

    private let currentDestinationFetcher: () -> SettingsCoordinator.InternalDestination?
    private let shouldAllowAutoDeselection: () -> Bool

    // MARK: - Lifecycle

    init(
        currentDestinationFetcher: @escaping () -> SettingsCoordinator.InternalDestination?,
        shouldAllowAutoDeselection: @escaping () -> Bool
    ) {
        self.currentDestinationFetcher = currentDestinationFetcher
        self.shouldAllowAutoDeselection = shouldAllowAutoDeselection
        
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
        if shouldAllowAutoDeselection() {
            indexPathsForSelectedItems?.forEach {
                deselectItem(at: $0, animated: false)
            }
        }
        else {
            guard let destination = currentDestinationFetcher(),
                  let dataSource = dataSource as? SettingsCollectionViewDataSource,
                  let row = SettingsCollectionViewDataSource.Row.row(for: destination),
                  let index = dataSource.indexPathForItem(row) else {
                return
            }

            selectItem(at: index, animated: false, scrollPosition: .centeredVertically)
        }
    }
    
    func betaFeedbackCell() -> UICollectionViewCell? {
        guard let dataSource = dataSource as? SettingsCollectionViewDataSource,
              let index = dataSource.indexPathForItem(.betaFeedback), let cell = cellForItem(at: index) else {
            return nil
        }
        
        return cell
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
