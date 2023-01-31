//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

NS_ASSUME_NONNULL_BEGIN

@class TMAManagedObjectContext;

@interface DatabaseContext : NSObject

/**
 Main context, it's static
 */
@property (strong, nonatomic) TMAManagedObjectContext *main;

/**
 Working context, could be private or main context
 */
@property (strong, nonatomic) TMAManagedObjectContext *current;

- (instancetype)init NS_UNAVAILABLE;

/**
 Database contexts for persistent coordinator. Important: use current context (could be main or private context).
 
 @param persistentCoordinator   see DatabaseManager
 @param forBackgroundProcess    YES means it will be create a private context (as a child of the main context)
 */
- (instancetype)initWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator;

/**
 Database child context for background or main thread (queue) with persistent coordinator. Current context is child (private) context.

 @param persistentCoordinator               See DatabaseManager
 @param childContextforBackgroundProcess    With new child context for background or main thread (queue)
 */
- (instancetype)initWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator withCildContextforBackgroundProcess:(BOOL)childContextforBackgroundProcess;

#ifdef DEBUG

/**
 Set database contexts just for testing.
 
 @param mainCnx Main NSManagedObjectContext
 @param backgroundCnx Background NSManagedObjectContext
 */
- (instancetype)initWithMainContext:(nonnull NSManagedObjectContext *)mainCnx backgroundContext:(nullable NSManagedObjectContext *)backgroundCnx;

#endif

/// A new background context directly accessing the persistent store [Workaround]
///
/// In our current architecture all background (private) contexts are child contexts of the main context. This leads to a crash in Threema on iOS 13 when a background context is
/// used in a `NSFetchedResultsController`. This is a workaround to resolve this problem especially for `MessageProvider`.
///
/// If you're not sure you need this use `EntityManager(forBackgroundProcess: true)`.
///
/// @param persistentCoordinator  Persistent store coordinator to use (from `DatabaseManager`)
+ (TMAManagedObjectContext *)directBackgroundContextWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator;

/**
 Set main DB context to nil. [Workaround]
 
 This should only be used in the notification extension.
 */
+ (void)reset;

@end

NS_ASSUME_NONNULL_END
