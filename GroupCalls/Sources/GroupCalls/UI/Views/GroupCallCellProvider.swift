import Foundation
import UIKit

enum GroupCallCellProvider {
    @MainActor static func registerCells(in collectionView: UICollectionView) {
        collectionView.register(
            GroupCallParticipantCell.self,
            forCellWithReuseIdentifier: GroupCallParticipantCell.reuseIdentifier
        )
    }
    
    // TODO: (IOS-4049) Move cell provider here
}
