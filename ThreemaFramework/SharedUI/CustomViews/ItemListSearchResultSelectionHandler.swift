import CoreData

public typealias ItemID = NSManagedObjectID

public protocol ItemListSearchResultSelectionHandler: AnyObject {
    func didSelect(id: ItemID)
    func didDeselect(id: ItemID)
    func selectionFor(id: ItemID) -> Bool
}
