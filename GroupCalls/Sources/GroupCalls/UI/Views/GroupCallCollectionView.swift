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
    
    // MARK: - Private Properties

    private var viewModel: GroupCallViewModel
    private var groupCallDataSource: UICollectionViewDataSource?
    private var updateVideoTask: Task<Void, Never>?
    private var previouslyVisibleParticipantCells = Set<GroupCallParticipantCell>()

    // MARK: - Lifecycle
    
    init(groupCallViewModel: GroupCallViewModel) {
        self.viewModel = groupCallViewModel
        super.init(
            frame: .zero,
            collectionViewLayout: LayoutProvider
                .createLayout(numberOfParticipants: viewModel.getNumberOfParticipants())
        )

        backgroundColor = .black

        delegate = self

        self.groupCallDataSource = GroupCallCollectionViewDataSource(collectionView: self, viewModel: viewModel)
        dataSource = groupCallDataSource
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    // MARK: - UICollectionViewDelegate

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? GroupCallParticipantCell else {
            return
        }
        
        Task {
            await viewModel.rendererView(for: cell.participantID!, rendererView: cell.videoRendererView)
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? GroupCallParticipantCell else {
            return
        }
        
        Task {
            await self.viewModel.remove(for: cell.participantID!, rendererView: cell.videoRendererView)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVideoTask?.cancel()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateVideo()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateVideo()
        }
    }
    
    public func updateLayout() {
        collectionViewLayout = LayoutProvider.createLayout(numberOfParticipants: viewModel.getNumberOfParticipants())
    }
    
    private func updateVideo() {
        updateVideoTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled {
                return
            }
            let visibleParticipantCells = visibleCells.compactMap { $0 as? GroupCallParticipantCell }
            await handleChangeOfVisibleParticipants(visibleCells: Set(visibleParticipantCells))
        }
    }
    
    private func handleChangeOfVisibleParticipants(visibleCells: Set<GroupCallParticipantCell>) async {
        let removedParticipantCells = previouslyVisibleParticipantCells.subtracting(visibleCells)
        let addedParticipantCells = visibleCells.subtracting(previouslyVisibleParticipantCells)
        
        for removedParticipantCell in removedParticipantCells {
            Task {
                await viewModel.unsubscribeVideo(for: removedParticipantCell.participantID!)
                removedParticipantCell.videoRendererView.alpha = 0.0
            }
        }
        
        for addedParticipantCell in addedParticipantCells {
            Task {
                await viewModel.subscribeVideo(for: addedParticipantCell.participantID!)
                addedParticipantCell.videoRendererView.alpha = 1.0
            }
        }
        
        previouslyVisibleParticipantCells = visibleCells
    }
}
