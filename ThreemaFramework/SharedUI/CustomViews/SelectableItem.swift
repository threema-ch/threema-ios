public struct SelectableItem {

    // MARK: - Public types

    public enum Item {
        case contact(Contact)
        case group(Group)
        case distributionList(DistributionList)
    }

    // MARK: - Public properties

    public let id: ItemID
    public let item: Item
    public let isSelected: Bool

    // MARK: - Lifecycle

    public init(id: ItemID, item: Item, isSelected: Bool) {
        self.id = id
        self.item = item
        self.isSelected = isSelected
    }
}
