import CoreData
import Foundation

extension NSManagedObjectContext {
    /// Checks if the current managed object models identifier contains "Encrypted"
    var usesAdditionallyEncryptedModel: Bool {
        guard let identifier = persistentStoreCoordinator?.managedObjectModel.versionIdentifiers.first as? String else {
            fatalError("Version Identifier not set for model version in model inspector.")
        }
        
        return identifier.contains("Encrypted")
    }
}
