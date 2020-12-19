//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

@protocol GroupMessageProcessorDelegate <NSObject>

- (void)startProcessPendingGroupMessages;

@end


@interface GroupMessageProcessor : NSObject

@property BOOL isNewGroup;

@property BOOL addToPendingMessages;

@property id<GroupMessageProcessorDelegate> delegate;

+ (instancetype)groupMessageProcessorForMessage:(AbstractGroupMessage *)message;

- (void)handleMessageOnCompletion:(void (^)(BOOL))onCompletion onError:(void(^)(NSError *error))onError;

- (Conversation *)conversation;

@end
