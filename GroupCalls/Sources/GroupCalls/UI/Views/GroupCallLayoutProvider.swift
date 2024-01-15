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

import Foundation
import UIKit

class GroupCallLayoutProvider {
    
    // TODO: (IOS-4049) Remove `view` hack if possible
    
    @MainActor static func createLayout(
        numberOfParticipants: Int,
        view: UIView
    ) -> UICollectionViewCompositionalLayout {
        // TODO: (IOS-4049) Decide layout based on `UIUserInterfaceSizeClass` in the trait collection instead of this
        if UIDevice.current.userInterfaceIdiom == .pad {
            return createLayoutForPads(numberOfParticipants: numberOfParticipants, view: view)
        }
        else {
            return createLayoutForPhones(numberOfParticipants: numberOfParticipants, view: view)
        }
    }
    
    // MARK: - Phone
    
    @MainActor private static func createLayoutForPhones(numberOfParticipants: Int, view: UIView)
        -> UICollectionViewCompositionalLayout {
        let inset: CGFloat = 2 // TODO: (IOS-4049) Add to config
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(verticalFractionPhone(numberOfParticipants: numberOfParticipants)),
            heightDimension: .fractionalHeight(1.0)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(cellHeightFactorPhone(numberOfParticipants: numberOfParticipants, view: view))
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        let layout = UICollectionViewCompositionalLayout(section: section)

        return layout
    }
    
    @MainActor private static func cellHeightFactorPhone(numberOfParticipants: Int, view: UIView) -> Double {
        let safeAreaHeight: Double
        if view.bounds.height != 0 {
            safeAreaHeight = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        }
        else {
            // Fallback to never return 0
            safeAreaHeight = UIScreen.main.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        }
        
        assert(safeAreaHeight != 0.0, "This should never return 0")
        
        switch numberOfParticipants {
        case 2...:
            return safeAreaHeight / 2
        default:
            return safeAreaHeight
        }
    }
    
    private static func verticalFractionPhone(numberOfParticipants: Int) -> Double {
        switch numberOfParticipants {
        case 3...:
            return 0.5
        default:
            return 1.0
        }
    }
    
    // MARK: - Pad
    
    @MainActor private static func createLayoutForPads(
        numberOfParticipants: Int,
        view: UIView
    ) -> UICollectionViewCompositionalLayout {
        
        let inset: CGFloat = 5 // TODO: (IOS-4049) Add to config
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(verticalFractionPad(numberOfParticipants: numberOfParticipants, view: view)),
            heightDimension: .fractionalHeight(1.0)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(cellHeightFactorPad(numberOfParticipants: numberOfParticipants, view: view))
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        // If this is true we have have an infinite loop
        assert(
            itemSize.widthDimension.dimension != 0.0 && groupSize.heightDimension.dimension != 0.0,
            "Both sizes should never be 0"
        )
        
        let section = NSCollectionLayoutSection(group: group)
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)

        return layout
    }
    
    @MainActor private static func cellHeightFactorPad(numberOfParticipants: Int, view: UIView) -> Double {
        let safeAreaHeight: Double
        if view.bounds.height != 0 {
            safeAreaHeight = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        }
        else {
            // Fallback to never return 0
            safeAreaHeight = UIScreen.main.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        }
        
        assert(safeAreaHeight != 0.0, "This should never return 0")
        
        switch numberOfParticipants {
        case 7...:
            return safeAreaHeight / 3
        case 3...6:
            return safeAreaHeight / 2
        default:
            return safeAreaHeight
        }
    }
    
    @MainActor private static func verticalFractionPad(numberOfParticipants: Int, view: UIView) -> Double {
        let safeAreaWidth: Double
        if view.bounds.height != 0 {
            safeAreaWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        }
        else {
            // Fallback to never return 0
            safeAreaWidth = UIScreen.main.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        }
        
        assert(safeAreaWidth != 0.0, "This should never return 0")
        
        switch numberOfParticipants {
        case 5...:
            return safeAreaWidth / 3
        case 2...4:
            return safeAreaWidth / 2
        default:
            return safeAreaWidth
        }
    }
}
