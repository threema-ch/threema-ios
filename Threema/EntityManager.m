//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "EntityManager.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ErrorHandler.h"
#import "DatabaseManager.h"
#import "BackgroundTaskManagerProxy.h"
#import "Utils.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation EntityManager {
    DatabaseContext *dbContext;
}

- (instancetype)init
{
    return [self initForBackgroundProcess:NO];
}

- (instancetype)initForBackgroundProcess:(BOOL)forBackgroundProcess
{
    self = [super init];
    if (self) {
        dbContext = [[DatabaseManager dbManager] getDatabaseContext:forBackgroundProcess];
        _entityCreator = [[EntityCreator alloc] initWith:dbContext.current];
        _entityFetcher = [[EntityFetcher alloc] initWith:dbContext.current];
        _entityDestroyer = [[EntityDestroyer alloc] initWithManagedObjectContext:dbContext.current];
    }
    return self;
}

- (void)refreshObject:(NSManagedObject *)object
         mergeChanges:(BOOL)flag {
    if (object != nil) {
        [self performBlockAndWait:^{
           [dbContext.current refreshObject:object mergeChanges:flag];
        }];
    }
}

- (instancetype)initWithDatabaseContext:(DatabaseContext *)context
{
    self = [super init];
    if (self) {
        dbContext = context;
        _entityCreator = [[EntityCreator alloc] initWith:dbContext.current];
        _entityFetcher = [[EntityFetcher alloc] initWith:dbContext.current];
        _entityDestroyer = [[EntityDestroyer alloc] initWithManagedObjectContext:dbContext.current];
    }
    return self;
}

- (void)performBlockAndWait:(void (^)(void))block  {
    [dbContext.current performBlockAndWait:^{
        if (block) {
            block();
        }
    }];
}

- (void)performBlock:(void (^)(void))block  {
    [dbContext.current performBlock:^{
        if (block) {
            block();
        }
    }];
}

- (void)performAsyncBlockAndSafe:(void (^)(void))block  {
    // saves always on main queue
    NSString *identifier = [BackgroundTaskManagerProxy counterWithIdentifier:kAppCoreDataSaveBackgroundTask];
    [BackgroundTaskManagerProxy newBackgroundTaskWithKey:identifier timeout:kAppCoreDataSaveBackgroundTaskTime completionHandler:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [dbContext.current performBlock:^{
            [self internalPerformWithIdentifier:identifier blockAndSave:block];
        }];
    });
}

- (void)performSyncBlockAndSafe:(void (^)(void))block  {
    // saves always on main queue
    NSString *identifier = [BackgroundTaskManagerProxy counterWithIdentifier:kAppCoreDataSaveBackgroundTask];
    [BackgroundTaskManagerProxy newBackgroundTaskWithKey:identifier timeout:kAppCoreDataSaveBackgroundTaskTime completionHandler:nil];
    if ([self isMainQueue]) {
        [dbContext.current performBlockAndWait:^{
            [self internalPerformWithIdentifier:identifier blockAndSave:block];
        }];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [dbContext.current performBlockAndWait:^{
                [self internalPerformWithIdentifier:identifier blockAndSave:block];
            }];
        });
    }
}

- (BOOL)isMainQueue {
    return [[NSOperationQueue currentQueue] underlyingQueue] == dispatch_get_main_queue();
}

- (void)internalPerformWithIdentifier:(NSString *)identifier blockAndSave:(void (^)(void))block  {
    if (block) {
        block();
    }
    
    if ([dbContext.current hasChanges]) {
        [self internalSave:^{
            [BackgroundTaskManagerProxy cancelBackgroundTaskWithKey:identifier];
        }];
    } else {
        [BackgroundTaskManagerProxy cancelBackgroundTaskWithKey:identifier];
    }
}

- (void)internalSave:(void (^)(void))onCompletion {
    if (ddLogLevel == DDLogLevelVerbose) {        
        DDLogVerbose(@"inserted objects: %@", [dbContext.current insertedObjects]);
        DDLogVerbose(@"updated objects: %@", [dbContext.current updatedObjects]);
        DDLogVerbose(@"deleted objects: %@", [dbContext.current deletedObjects]);
    }
    
    NSError *error = nil;
    if (![dbContext.current save:&error]) {
        DDLogError(@"Error saving context %@, %@", error, [error userInfo]);
        [ErrorHandler abortWithError: error];

        if (onCompletion != nil) {
            onCompletion();
        }
    }
    else if ([dbContext.current parentContext] != nil) {
        // asynchronously save parent context (changes were pushed by save in child context)
        [dbContext.main performBlock:^{
            NSError *error = nil;
            if (![dbContext.main save:&error]) {
                DDLogError(@"Error saving context %@, %@", error, [error userInfo]);
                [ErrorHandler abortWithError: error];

                if (onCompletion != nil) {
                    onCompletion();
                }
            }

            if (onCompletion != nil) {
                onCompletion();
            }
        }];
    }
    else {
        if (onCompletion != nil) {
            onCompletion();
        }
    }
}

- (void)rollback {
    [dbContext.current rollback];
}

- (Conversation *)conversationForContact:(Contact *)contact createIfNotExisting:(BOOL) create {
    Conversation *conversation = [[self entityFetcher] conversationForContact:contact];
    if (create && conversation == nil) {
        conversation = [self entityCreator].conversation;
        conversation.contact = contact;
        if (![Utils hideThreemaTypeIconForContact:contact]) {
            // add work info as first message
            SystemMessage *systemMessage = [self.entityCreator systemMessageForConversation:conversation];
            systemMessage.type = [NSNumber numberWithInteger:kSystemMessageContactOtherAppInfo];
            systemMessage.remoteSentDate = [NSDate date];
        }
    }
    
    return conversation;
}

@end
