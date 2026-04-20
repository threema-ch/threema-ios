public protocol ItemSelectionHandler: AnyObject, ItemListSearchResultSelectionHandler {
    func selectedItems() -> [SelectableItem]
}
