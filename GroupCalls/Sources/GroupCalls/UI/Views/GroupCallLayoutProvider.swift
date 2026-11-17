import Foundation
import UIKit

enum GroupCallLayoutProvider {
    
    // TODO: (IOS-4049) Remove `view` hack if possible
    
    /// Creates the layout for the participant cells
    ///
    /// The sections are created whenever the layout is (re-)calculated, e.g. on bounds changes, so the sizes always
    /// match the current bounds and safe area of `view`.
    /// - Parameters:
    ///   - numberOfParticipants: Number of participants to lay out
    ///   - view: View whose bounds minus its safe area are available for the cells
    @MainActor static func createLayout(
        numberOfParticipants: Int,
        view: UIView
    ) -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak view] _, environment in
            let safeAreaSize = safeAreaSize(of: view, in: environment)
            
            // Nothing is visible before the first layout pass with real bounds, avoid absolute sizes of 0
            guard safeAreaSize.width > 0, safeAreaSize.height > 0 else {
                return createPlaceholderSection()
            }
            
            // TODO: (IOS-4049) Decide layout based on `UIUserInterfaceSizeClass` in the trait collection instead of this
            return if UIDevice.current.userInterfaceIdiom == .pad {
                createSectionForPads(numberOfParticipants: numberOfParticipants, safeAreaSize: safeAreaSize)
            }
            else {
                createSectionForPhones(numberOfParticipants: numberOfParticipants, safeAreaSize: safeAreaSize)
            }
        }
    }
    
    /// Size of `view` without its safe area, or the size of the layout container until `view` is laid out
    @MainActor private static func safeAreaSize(
        of view: UIView?,
        in environment: NSCollectionLayoutEnvironment
    ) -> CGSize {
        guard let view, view.bounds.width != 0, view.bounds.height != 0 else {
            // Fallback to never return 0
            return environment.container.effectiveContentSize
        }
        
        return CGSize(
            width: view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right,
            height: view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        )
    }
    
    /// Section filling the container, used until the available size is known
    private static func createPlaceholderSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: size,
            subitems: [NSCollectionLayoutItem(layoutSize: size)]
        )
        return NSCollectionLayoutSection(group: group)
    }
    
    // MARK: - Phone
    
    private static func createSectionForPhones(
        numberOfParticipants: Int,
        safeAreaSize: CGSize
    ) -> NSCollectionLayoutSection {
        let inset: CGFloat = 2 // TODO: (IOS-4049) Add to config
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(verticalFractionPhone(numberOfParticipants: numberOfParticipants)),
            heightDimension: .fractionalHeight(1.0)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(
                cellHeightFactorPhone(numberOfParticipants: numberOfParticipants, safeAreaSize: safeAreaSize)
            )
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        return NSCollectionLayoutSection(group: group)
    }
    
    private static func cellHeightFactorPhone(numberOfParticipants: Int, safeAreaSize: CGSize) -> Double {
        let safeAreaHeight = Double(safeAreaSize.height)
        
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
            0.5
        default:
            1.0
        }
    }
    
    // MARK: - Pad
    
    private static func createSectionForPads(
        numberOfParticipants: Int,
        safeAreaSize: CGSize
    ) -> NSCollectionLayoutSection {
        
        let inset: CGFloat = 5 // TODO: (IOS-4049) Add to config
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(
                verticalFractionPad(numberOfParticipants: numberOfParticipants, safeAreaSize: safeAreaSize)
            ),
            heightDimension: .fractionalHeight(1.0)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(
                cellHeightFactorPad(numberOfParticipants: numberOfParticipants, safeAreaSize: safeAreaSize)
            )
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
        
        return NSCollectionLayoutSection(group: group)
    }
    
    private static func cellHeightFactorPad(numberOfParticipants: Int, safeAreaSize: CGSize) -> Double {
        let safeAreaHeight = Double(safeAreaSize.height)
        
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
    
    private static func verticalFractionPad(numberOfParticipants: Int, safeAreaSize: CGSize) -> Double {
        let safeAreaWidth = Double(safeAreaSize.width)
        
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
