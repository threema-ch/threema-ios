import Combine
import Foundation
import UIKit

final class GroupCallCollectionViewDataSource: UICollectionViewDiffableDataSource<
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
                if let oldParticipant = cell.participant?.participantID, oldParticipant.id != itemIdentifier.id {
                    await viewModel.removeRendererView(for: oldParticipant, rendererView: cell.videoRendererView)
                    cell.resetRendererView()
                }
                
                let fetchedParticipant = viewModel.participant(for: itemIdentifier)
                cell.participant = fetchedParticipant
                
                // Workaround for when running screenshots
                guard !(fetchedParticipant?.dependencies.isRunningForScreenshots ?? false) else {
                    return
                }
                
                if await fetchedParticipant?.videoMuteState == .muted {
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
