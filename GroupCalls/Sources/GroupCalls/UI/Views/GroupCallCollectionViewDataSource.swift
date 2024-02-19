//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
            
            Task {
                if let oldParticipant = cell.participantID, oldParticipant.id != itemIdentifier.id {
                    await viewModel.removeRendererView(for: oldParticipant, rendererView: cell.videoRendererView)
                    cell.resetRendererView()
                }
                
                let fetchedParticipant = viewModel.participant(for: itemIdentifier)
                cell.participantID = itemIdentifier
                cell.participant = fetchedParticipant
                
                // Workaround for when running screenshots
                guard !(fetchedParticipant?.dependencies.isRunningForScreenshots ?? false) else {
                    return
                }
                
                if fetchedParticipant?.videoMuteState == .muted {
                    cell.hideRenderer()
                    await viewModel.removeRendererView(for: itemIdentifier, rendererView: cell.videoRendererView)
                }
                else {
                    await viewModel.addRendererView(for: itemIdentifier, rendererView: cell.videoRendererView)
                    cell.showRenderer()
                }
            }
            
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
