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

import Foundation
import UIKit

class GroupCallLayoutProvider {
    
    @MainActor static func createLayout(numberOfParticipants: Int) -> UICollectionViewCompositionalLayout {
        // TODO: (IOS-4049) Shouldn't this be based on `UIUserInterfaceSizeClass` in the trait collection?
        if UIDevice.current.userInterfaceIdiom == .pad {
            return createLayoutForPads(numberOfParticipants: numberOfParticipants)
        }
        else {
            return createLayoutForPhones(numberOfParticipants: numberOfParticipants)
        }
    }
    
    // MARK: - Phone
    
    @MainActor private static func createLayoutForPhones(numberOfParticipants: Int)
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
            heightDimension: .fractionalHeight(cellHeightFactorPhone(numberOfParticipants: numberOfParticipants))
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsetsReference = .safeArea // TODO: (IOS-4049) Verify insets
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = .layoutMargins // TODO: (IOS-4049) Verify insets
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)

        return layout
    }
    
    private static func cellHeightFactorPhone(numberOfParticipants: Int) -> Double {
        switch numberOfParticipants {
        case 5...:
            return 0.475
        case 2..<5:
            return 0.5
        default:
            return 1.0
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
    
    @MainActor private static func createLayoutForPads(numberOfParticipants: Int)
        -> UICollectionViewCompositionalLayout {
        let inset: CGFloat = 5 // TODO: (IOS-4049) Add to config
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(verticalFractionPad(numberOfParticipants: numberOfParticipants)),
            heightDimension: .fractionalHeight(1.0)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(cellHeightFactorPad(numberOfParticipants: numberOfParticipants))
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsetsReference = .safeArea // TODO: (IOS-4049) Verify insets
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = .layoutMargins // TODO: (IOS-4049) Verify insets
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)

        return layout
    }
    
    private static func cellHeightFactorPad(numberOfParticipants: Int) -> Double {
        switch numberOfParticipants {
        case 3, 4:
            return 0.5
        case 5...:
            return 0.33
        default:
            return 1.0
        }
    }
    
    private static func verticalFractionPad(numberOfParticipants: Int) -> Double {
        switch numberOfParticipants {
        case 2, 3, 4:
            return 0.5
        case 5...:
            return 0.33
        default:
            return 1.0
        }
    }
}
