//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DatabaseContext.h"

typedef enum : NSUInteger {
    RequiresMigrationNone = 0,
    RequiresMigration = 1,
    RequiresMigrationError = 2
} StoreRequiresMigration;

@interface DatabaseManager : NSObject

@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (readonly) NSError *storeError;

+ (instancetype)dbManager;

/**
 Get database main context for main thread (queue).
*/
- (DatabaseContext *)getDatabaseContext;

/**
 Get database context with child context for background or main thread (queue).

 @param withChildContextforBackgroundProcess    Child context for background thread or main thread
*/
- (DatabaseContext *)getDatabaseContext:(BOOL)withChildContextforBackgroundProcess
    NS_SWIFT_NAME(getDatabaseContext(withChildContextforBackgroundProcess:));

+ (NSURL *)storeUrl NS_SWIFT_NAME(storeURL());

+ (BOOL)storeExists;

- (StoreRequiresMigration)storeRequiresMigration;

- (BOOL)storeRequiresImport;

- (NSError *)storeError;

- (BOOL)canMigrateDB;

- (void)doMigrateDB;

- (void)copyImportedDatabase;

- (void)eraseDB;

- (BOOL)shouldUpdateProtection;

- (void)updateProtection;

- (void)disableBackupForDatabaseDirectory:(BOOL)disable;

/**
 Refreshes all registered objects in DB main context. Is useful for notification extension.
 */
- (void)refreshAllObjects;

- (void)refreshDirtyObjectIDs:(NSDictionary *)changes intoContext:(NSManagedObjectContext *)context;

/// Refreshes all dirty objects, will be used within the app to apply changes from notification/share extension.
/// @param removeExisting: Remove dirty objects from AppDefaults
- (void)refreshDirtyObjects:(BOOL)removeExisting;

/**
 Adds objects as dirty. Used for changes in notification/share extension.
 */
- (void)addDirtyObject:(NSManagedObject *)object;
- (void)addDirtyObjectID:(NSManagedObjectID * _Nonnull)objectID;

/**
 Replace database and external data with version in applicationDocuments/ThreemaDataOldVersion, for testing database migration.
*/
- (BOOL)copyOldVersionOfDatabase;

@end
