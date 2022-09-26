//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
static dispatch_queue_t dispatchQueue;

+ (void)initialize {
    if (dispatchQueue == nil) {
        dispatchQueue = dispatch_queue_create("ch.threema.DatabaseContext.main", NULL);
    }
}

- (instancetype)initWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator
{
    self = [super init];
    if (self) {
        dispatch_sync(dispatchQueue, ^{
            if (mainContext == nil) {
                mainContext = [[TMAManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
                [mainContext setPersistentStoreCoordinator:persistentCoordinator];
                [mainContext setMergePolicy:NSOverwriteMergePolicy];
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
        [privateContext setParentContext:mainContext];
    }
    return self;
}

#ifdef DEBUG

- (instancetype)initWithMainContext:(nonnull TMAManagedObjectContext *)mainCnx backgroundContext:(nullable TMAManagedObjectContext *)backgroundCnx
{
    self = [super init];
    if (self) {
        mainContext = mainCnx;

        if (privateContext) {
            privateContext = backgroundCnx;
            [privateContext setParentContext:mainContext];
        }
    }
    return self;
}


#endif

+ (TMAManagedObjectContext *)directBackgroundContextWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator {
    TMAManagedObjectContext *context = [[TMAManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setPersistentStoreCoordinator:persistentCoordinator];
    return context;
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

+ (void)reset {
    dispatch_sync(dispatchQueue, ^{
        if (mainContext != nil) {
            mainContext = nil;
        }
    });
}

@end
