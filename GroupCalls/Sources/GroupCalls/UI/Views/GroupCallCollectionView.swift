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

final class GroupCallCollectionView: UICollectionView, UICollectionViewDelegate {
    
    // MARK: - Private properties

    private var viewModel: GroupCallViewModel
    private var groupCallDataSource: GroupCallCollectionViewDataSource?
    
    private var updateVideoTask: Task<Void, Never>?
    
    private var previouslyVisibleCellsParticipantIDs = Set<ParticipantID>()
    
    // MARK: - Lifecycle
    
    init(groupCallViewModel: GroupCallViewModel) {
        self.viewModel = groupCallViewModel

        super.init(
            frame: .zero,
            collectionViewLayout: GroupCallLayoutProvider.createLayout(
                numberOfParticipants: viewModel.numberOfParticipants,
                view: UIView()
            )
        )

        backgroundColor = .black

        delegate = self

        self.groupCallDataSource =
            GroupCallCollectionViewDataSource(collectionView: self, viewModel: viewModel)
        dataSource = groupCallDataSource
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    // MARK: - UICollectionViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // TODO: (IOS-4058) refactor sub/unsub
        updateVideoTask?.cancel()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // TODO: (IOS-4058) refactor sub/unsub
        updateVideo()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // TODO: (IOS-4058) refactor sub/unsub
        if !decelerate {
            updateVideo()
        }
    }
    
    public func updateLayout() {
        let newLayout = GroupCallLayoutProvider.createLayout(
            numberOfParticipants: viewModel.numberOfParticipants,
            view: self
        )
        
        // This prevents jumping of the scroll position if the fractional height of the layout is not 1 or 0.5.
        // But iff animated is false
        // TODO: (IOS-4049) Is this still needed?
        let lastContentOffset = contentOffset
        setCollectionViewLayout(newLayout, animated: false) { _ in
            self.contentOffset = lastContentOffset
        }
    }
    
    private func updateVideo() {
        updateVideoTask = Task {
            
            do {
                try await Task.sleep(seconds: 0.2)
            }
            catch {
                // Task was cancelled
                return
            }
            
            let visibleParticipantCells = visibleCells.compactMap { $0 as? GroupCallParticipantCell }
            await handleChangeOfVisibleParticipants(visibleCells: Set(visibleParticipantCells))
        }
    }
    
    private func handleChangeOfVisibleParticipants(visibleCells: Set<GroupCallParticipantCell>) async {
        let visibleCellsParticipantIDs = Set(visibleCells.compactMap(\.participantID))
        let removedCellsParticipantIDs = previouslyVisibleCellsParticipantIDs.subtracting(visibleCellsParticipantIDs)
        let addedCellsParticipantIDs = visibleCellsParticipantIDs.subtracting(previouslyVisibleCellsParticipantIDs)
        
        // We fill the previouslyVisibleCellsParticipantIDs when entering the first time
        if previouslyVisibleCellsParticipantIDs.isEmpty {
            previouslyVisibleCellsParticipantIDs = visibleCellsParticipantIDs
            return
        }
        
        for removedParticipantID in removedCellsParticipantIDs {
            Task {
                await viewModel.unsubscribeVideo(for: removedParticipantID)
            }
        }
        
        for addedCellsParticipantID in addedCellsParticipantIDs {
            Task {
                await viewModel.subscribeVideo(for: addedCellsParticipantID)
            }
        }
        
        previouslyVisibleCellsParticipantIDs = visibleCellsParticipantIDs
    }
}
