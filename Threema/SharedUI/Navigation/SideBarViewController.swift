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

class SidebarViewController: UIViewController, UICollectionViewDelegate {
    
    enum SideBarSection: String {
        case tabs
    }
    
    weak var coordinator: AppCoordinator?
    
    private lazy var dataSource: UICollectionViewDiffableDataSource<SideBarSection, TabBarController.TabBarItem> = {
        let cellRegistration = UICollectionView
            .CellRegistration<UICollectionViewListCell, TabBarController.TabBarItem> { cell, _, item in
                var content = cell.defaultContentConfiguration()
                content.text = item.title
                content.image = item.sideBarSymbol
                cell.contentConfiguration = content
            }
        
        return UICollectionViewDiffableDataSource<
            SideBarSection,
            TabBarController.TabBarItem
        >(collectionView: collectionView) {
            (
                collectionView: UICollectionView,
                indexPath: IndexPath,
                item: TabBarController.TabBarItem
            ) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
            
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        }
        
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        
        return collectionView
    }()
    
    // MARK: - Lifecycle
    
    init(coordinator: AppCoordinator?) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: (IOS-5209) Logo instead of title?
        navigationItem.title = TargetManager.appName
        navigationController?.navigationBar.prefersLargeTitles = false
        
        configureView()
        configureDataSource()
        setSelection()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setSelection()
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func configureDataSource() {
        let sections: [SideBarSection] = [.tabs]
        var snapshot = NSDiffableDataSourceSnapshot<SideBarSection, TabBarController.TabBarItem>()
        snapshot.appendSections(sections)
        snapshot.appendItems(TabBarController.TabBarItem.allCases, toSection: .tabs)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 0, let tab = TabBarController.TabBarItem(rawValue: indexPath.row) else {
            assertionFailure("Selected row has no matching tab item case.")
            return
        }
        
        coordinator?.swichtTab(to: tab)
    }
    
    // MARK: - Updates
    
    func setSelection() {
        guard let currentTab = coordinator?.currentTab else {
            return
        }
        
        guard collectionView.cellForItem(at: IndexPath(row: currentTab.rawValue, section: 0)) != nil else {
            return
        }
        
        collectionView.selectItem(
            at: IndexPath(row: currentTab.rawValue, section: 0),
            animated: false,
            scrollPosition: UICollectionView.ScrollPosition.centeredVertically
        )
    }
}
