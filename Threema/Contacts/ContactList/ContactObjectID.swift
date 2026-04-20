import Foundation

public protocol ContactObjectID: Identifiable, Hashable { }

// MARK: - NSManagedObjectID + ContactObjectID

extension NSManagedObjectID: ContactObjectID { }
