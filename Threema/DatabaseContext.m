//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

@implementation DatabaseContext  {
    NSManagedObjectContext *privateContext;
}

static NSManagedObjectContext *mainContext;
static dispatch_queue_t dispatchQueue;

+ (void)initialize {
    if (dispatchQueue == nil) {
        dispatchQueue = dispatch_queue_create("ch.threema.DatabaseContext.main", NULL);
    }
}

- (instancetype)initWithPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentCoordinator forBackgroundProcess:(BOOL)forBackgroundProcess
{
    self = [super init];
    if (self) {
        dispatch_sync(dispatchQueue, ^{
            if (mainContext == nil) {
                mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
                [mainContext setPersistentStoreCoordinator:persistentCoordinator];
                [mainContext setMergePolicy:NSOverwriteMergePolicy];
            }
        });
        
        if (forBackgroundProcess) {
            privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [privateContext setParentContext:mainContext];
        }
    }
    return self;
}

- (NSManagedObjectContext *)main
{
    return mainContext;
}

- (NSManagedObjectContext *)current
{
    return privateContext != nil ? privateContext : mainContext;
}

@end
