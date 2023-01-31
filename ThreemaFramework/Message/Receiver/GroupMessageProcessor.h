//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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
#import "AbstractGroupMessage.h"
#import "Conversation.h"
#import "UserSettings.h"

@interface GroupMessageProcessor : NSObject

@property BOOL addToPendingMessages;

/**
 @param message: Group message to process
 @param myIdentityStore: My identity store
 @param userSetting: User settings
 @param groupManager: Must be a id<GroupManagerProtocolObjc>, is NSObject because GroupManagerProtocolObjc is implemented in Swift (circularity #import not possible)
 @param entityManager: Must be an EntityManager, is NSObject because EntityManager is implemented in Swift (circularity #import not possible)
 */
- (nonnull instancetype)initWithMessage:(nonnull AbstractGroupMessage *)message myIdentityStore:(id<MyIdentityStoreProtocol> _Nonnull)myIdentityStore userSettings:(id<UserSettingsProtocol> _Nonnull)userSettings groupManager:(nonnull NSObject *)groupManagerObject entityManager:(nonnull NSObject *)entityManagerObject;

- (void)handleMessageOnCompletion:(void (^ _Nonnull)(BOOL))onCompletion onError:(void(^ _Nonnull)(NSError * _Nonnull error))onError;

- (nullable Conversation *)conversation;

@end
