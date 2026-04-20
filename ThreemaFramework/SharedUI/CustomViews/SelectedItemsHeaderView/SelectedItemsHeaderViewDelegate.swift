import Foundation

public protocol SelectedItemsHeaderViewDelegate: AnyObject {
    func header(_ header: SelectedItemsHeaderView, itemForIndexPath indexPath: IndexPath) -> SelectableItem?
}
