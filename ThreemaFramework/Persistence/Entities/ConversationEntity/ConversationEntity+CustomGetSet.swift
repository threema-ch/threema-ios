import Foundation

extension ConversationEntity {
    
    public var conversationCategory: Category {
        Category(rawValue: Int(truncating: category))!
    }
    
    public var conversationVisibility: Visibility {
        Visibility(rawValue: Int(truncating: visibility))!
    }
    
    public func changeCategory(to category: Category) {
        let categoryKey = "category"
        willChangeValue(forKey: categoryKey)
        setPrimitiveValue(category.rawValue as NSNumber, forKey: categoryKey)
        didChangeValue(forKey: categoryKey)
    }
    
    public func changeVisibility(to visibility: Visibility) {
        let visibilityKey = "visibility"
        willChangeValue(forKey: visibilityKey)
        setPrimitiveValue(visibility.rawValue as NSNumber, forKey: visibilityKey)
        didChangeValue(forKey: visibilityKey)
    }
}
