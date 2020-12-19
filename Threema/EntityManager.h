//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@interface EntityManager : NSObject

@property (readonly) EntityCreator *entityCreator;
@property (readonly) EntityFetcher *entityFetcher;
@property (readonly) EntityDestroyer *entityDestroyer;

- (instancetype)initForBackgroundProcess:(BOOL)forBackgroundProcess;

- (instancetype)initWithDatabaseContext:(DatabaseContext *)context;

- (void)refreshObject:(NSManagedObject *)object
         mergeChanges:(BOOL)flag;

- (void)rollback;

- (void)performAsyncBlockAndSafe:(void (^)(void))block;

- (void)performSyncBlockAndSafe:(void (^)(void))block;

- (void)performBlock:(void (^)(void))block;

- (void)performBlockAndWait:(void (^)(void))block;

// data access & creation helpers

- (Conversation *)conversationForContact:(Contact *)contact createIfNotExisting:(BOOL)create;

@end
