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
#import "DatabaseContext.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation DatabaseContext  {
    TMAManagedObjectContext *privateContext;
}

static TMAManagedObjectContext *mainContext;
static dispatch_queue_t mainContextQueue;

static NSMutableArray<TMAManagedObjectContext *> *directContexts;
static dispatch_queue_t directContextsQueue;

+ (void)initialize {
    if (mainContextQueue == nil) {
        mainContextQueue = dispatch_queue_create("ch.threema.DatabaseContext.mainContextQueue", NULL);
    }
    if (directContextsQueue == nil) {
        directContextsQueue = dispatch_queue_create("ch.threema.DatabaseContext.directContextsQueue", NULL);
    }
}

- (instancetype)initWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator
{
    self = [super init];
    if (self) {
        dispatch_sync(mainContextQueue, ^{
            if (mainContext == nil) {
                mainContext = [[TMAManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
                [mainContext setPersistentStoreCoordinator:persistentCoordinator];
                [mainContext setMergePolicy:NSOverwriteMergePolicy];
                mainContext.automaticallyMergesChangesFromParent = YES;
            }
        });
    }
    return self;
}

- (instancetype)initWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator withCildContextforBackgroundProcess:(BOOL)childContextforBackgroundProcess
{
    self = [self initWithPersistentCoordinator:persistentCoordinator];
    if (self) {
        privateContext = [[TMAManagedObjectContext alloc] initWithConcurrencyType:childContextforBackgroundProcess ? NSPrivateQueueConcurrencyType : NSMainQueueConcurrencyType];
        [privateContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
        [privateContext setParentContext:mainContext];
        privateContext.automaticallyMergesChangesFromParent = YES;
        
        // Listen to dirty object notifications to refresh private context
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDirtyObjects:) name:kNotificationDBRefreshedDirtyObjects object:nil];
    }
    return self;
}

#ifdef DEBUG

- (instancetype)initWithMainContext:(nonnull TMAManagedObjectContext *)mainCnx backgroundContext:(nullable TMAManagedObjectContext *)backgroundCnx
{
    self = [super init];
    if (self) {
        mainContext = mainCnx;
        mainContext.automaticallyMergesChangesFromParent = YES;

        if (backgroundCnx) {
            privateContext = backgroundCnx;
            [privateContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
            [privateContext setParentContext:mainContext];
            privateContext.automaticallyMergesChangesFromParent = YES;
        }
    }
    return self;
}

#endif

+ (TMAManagedObjectContext *)directBackgroundContextWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator {
    TMAManagedObjectContext *context = [[TMAManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setPersistentStoreCoordinator:persistentCoordinator];

    dispatch_sync(directContextsQueue, ^{
        if (directContexts == nil) {
            directContexts = [NSMutableArray new];
        }
        if ([directContexts containsObject:context] == NO) {
            [directContexts addObject:context];
        }
    });

    return context;
}

+ (void)removeDirectBackgroundContextWithContext:(nonnull __kindof NSManagedObjectContext *)context {
    dispatch_sync(directContextsQueue, ^{
        if (directContexts) {
            [directContexts removeObject:context];
        }
    });
}

- (TMAManagedObjectContext *)main
{
    NSAssert(mainContext != nil, @"This should not be used again after mainContext is reset");
    
    return mainContext;
}

- (TMAManagedObjectContext *)current
{
    NSAssert(mainContext != nil, @"This should not be used again after mainContext is reset");

    return privateContext != nil ? privateContext : mainContext;
}

- (NSArray<TMAManagedObjectContext *> *)directContexts {
    __block NSArray<TMAManagedObjectContext *> *contexts;
    dispatch_sync(directContextsQueue, ^{
        contexts = [directContexts copy];
    });
    return contexts;
}

#pragma mark - Private

- (void)refreshDirtyObjects:(NSNotification*)notification {
    NSSet<NSManagedObjectID *> *objectIDs = [notification.userInfo objectForKey:kKeyObjectIDs];
    
    // This notification should only be observed when a private context exists, but we check anyway
    if (privateContext) {
        for (NSManagedObject *objectID in objectIDs) {
            [privateContext performBlock:^{
                NSManagedObject *object = [privateContext objectWithID:objectID];
                [privateContext refreshObject:object mergeChanges:YES];
            }];
        }
    }
}

@end
