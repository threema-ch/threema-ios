import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

final class ConversationSelectionManager {
    
    struct SelectedItem {
        let conversation: ConversationEntity
        let indexPath: IndexPath
    }
    
    // MARK: - Properties
    
    private(set) var selectedItem: SelectedItem?
    var allowSelectionSetting = true
    
    var selectedConversation: ConversationEntity? {
        selectedItem?.conversation
    }
    
    private weak var tableView: UITableView?
    private let indexPathForConversation: (ConversationEntity?) -> IndexPath?
    private let isRegularSizeClass: () -> Bool
    private let clearsSelectionOnViewWillAppear: (Bool) -> Void
    
    // MARK: - Lifecycle
    
    init(
        tableView: UITableView,
        indexPathForConversation: @escaping (ConversationEntity?) -> IndexPath?,
        isRegularSizeClass: @escaping () -> Bool,
        clearsSelectionOnViewWillAppear: @escaping (Bool) -> Void
    ) {
        self.tableView = tableView
        self.indexPathForConversation = indexPathForConversation
        self.isRegularSizeClass = isRegularSizeClass
        self.clearsSelectionOnViewWillAppear = clearsSelectionOnViewWillAppear
    }
    
    // MARK: - Selection
    
    func select(conversation: ConversationEntity, at indexPath: IndexPath) {
        selectedItem = SelectedItem(
            conversation: conversation,
            indexPath: indexPath
        )
    }
    
    func setSelection(for conversation: ConversationEntity?) {
        guard
            let conversation,
            let indexPath = indexPathForConversation(conversation)
        else {
            deselectAll(animated: true)
            return
        }
        
        selectedItem = SelectedItem(
            conversation: conversation,
            indexPath: indexPath
        )
        
        /// We add a small delay to make sure the animation computes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.tableView?.selectRow(
                at: indexPath,
                animated: true,
                scrollPosition: .none
            )
        }
        
        DDLogInfo(
            "New selected conversation at: \(String(describing: indexPath))"
        )
    }
    
    func selectItemIfNeeded() {
        guard let selectedIndexPath = selectedItem?.indexPath else {
            return
        }
        
        tableView?.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .none)
    }
    
    func removeSelection() {
        selectedItem = nil
        deselectAll(animated: false)
    }
    
    func clearSelectedItemIfNeeded(at indexPath: IndexPath) {
        guard selectedItem?.indexPath == indexPath else {
            return
        }
        
        selectedItem = nil
    }
    
    // MARK: - View Lifecycle Support
    
    func handleViewWillAppear() {
        if allowSelectionSetting {
            clearsSelectionOnViewWillAppear(!isRegularSizeClass())
        }
        
        if isRegularSizeClass() {
            setSelection(for: selectedItem?.conversation)
        }
        else {
            selectedItem = nil
        }
    }
    
    // MARK: - Private
    
    private func deselectAll(animated: Bool) {
        tableView?.indexPathsForSelectedRows?.forEach {
            tableView?.deselectRow(at: $0, animated: animated)
        }
    }
}
