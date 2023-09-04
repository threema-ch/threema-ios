//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import Combine
import Foundation
import UIKit

class GroupCallCollectionViewDataSource: UICollectionViewDiffableDataSource<
    GroupCallCollectionViewDataSource.Section,
    ParticipantID
> {
    
    enum Section {
        case main
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var viewModel: GroupCallViewModel
    
    // MARK: - Lifecycle

    init(collectionView: UICollectionView, viewModel: GroupCallViewModel) {
        GroupCallCellProvider.registerCells(in: collectionView)
        
        self.viewModel = viewModel
        super.init(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            // TODO: (IOS-4049) Use cell provider?
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: GroupCallParticipantCell.reuseIdentifier,
                for: indexPath
            ) as! GroupCallParticipantCell
            
            cell.participantID = itemIdentifier
            cell.participant = viewModel.participant(for: itemIdentifier)
            
            cell.layer.cornerRadius = 5
            cell.layer.masksToBounds = true
            cell.layer.cornerCurve = .continuous
            
            return cell
        }
        
        subscribeToPublisher()
    }
    
    // MARK: - Private Functions

    private func subscribeToPublisher() {
        viewModel.$snapshotPublisher.sink { [weak self] snapshot in
            self?.apply(snapshot, animatingDifferences: false)
        }
        .store(in: &cancellables)
    }
}