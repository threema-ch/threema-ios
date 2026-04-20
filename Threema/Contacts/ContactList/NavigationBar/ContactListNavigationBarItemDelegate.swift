import Foundation

protocol ContactListActionDelegate: AnyObject {
    func add(_ item: ContactListAddItem)
    func filterChanged(_ item: ContactListFilterItem)
    func didToggleWorkContacts(_ isTurnedOn: Bool)
    func didSelect(_ destination: ContactListCoordinator.InternalDestination)
}
