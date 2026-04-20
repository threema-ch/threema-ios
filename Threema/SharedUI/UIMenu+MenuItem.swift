import UIKit

extension UIMenu {
    convenience init<Item: MenuItem>(_ didSelect: @escaping (Item) -> Void) {
        self.init(children: Item.allCases.map {
            item in
            UIAction(
                title: item.label,
                image: item.icon.uiImage,
                attributes: !item.enabled ? .hidden : []
            ) { _ in
                didSelect(item)
            }
        })
    }
}
