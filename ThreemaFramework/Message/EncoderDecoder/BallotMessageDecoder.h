//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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
#import <ThreemaFramework/BoxBallotCreateMessage.h>
#import <ThreemaFramework/BoxBallotVoteMessage.h>
#import <ThreemaFramework/GroupBallotCreateMessage.h>
#import <ThreemaFramework/GroupBallotVoteMessage.h>

@interface BallotMessageDecoder : NSObject

- (instancetype)init NS_UNAVAILABLE;

/**
 Create instance of BallotMessageDecoder.
 
 @param entityManagerObject Must be type of EntityManager class. Parameter Is NSObject because EntityManager is in Swift!
 */
- (instancetype)initWith:(NSObject *)entityManagerObject;

/**
 Decode abstarct ballot create message.

 @param boxMessage Abstract ballot create message
 @param senderObject Sender object of type `ContactEntity`
 @param conversationObject Conversation object of type `ConversationEntity`
 @param onCompletion With parameter of type `BallotMessageEntity` as result
 @param onError With parameter of type `NSError`
 */
- (void)decodeCreateBallotFromBox:(nonnull BoxBallotCreateMessage *)boxMessage sender:(nullable NSObject *)senderObject conversation:(nonnull NSObject *)conversationObject onCompletion:(void(^ _Nonnull)(NSObject * _Nonnull))onCompletion onError:(void(^ _Nonnull)(NSError * _Nonnull))onError;

/**
 Decode abstarct group ballot create message.

 @param boxMessage Abstract group ballot create message
 @param senderObject Sender object of type `ContactEntity`
 @param conversationObject Conversation object of type `ConversationEntity`
 @param onCompletion With parameter of type `BallotMessageEntity` as result
 @param onError With parameter of type `NSError`
 */
- (void)decodeCreateBallotFromGroupBox:(nonnull GroupBallotCreateMessage *)boxMessage sender:(nullable NSObject *)senderObject conversation:(nonnull NSObject *)conversationObject onCompletion:(void(^ _Nonnull)(NSObject * _Nonnull))onCompletion onError:(void(^ _Nonnull)(NSError * _Nonnull))onError;

+ (NSString *)decodeCreateBallotTitleFromBox:(BoxBallotCreateMessage *)boxMessage;
+ (NSNumber *)decodeNotificationCreateBallotStateFromBox:(BoxBallotCreateMessage *)boxMessage;

- (BOOL)decodeVoteFromBox:(BoxBallotVoteMessage *)boxMessage;
- (BOOL)decodeVoteFromGroupBox:(GroupBallotVoteMessage *)boxMessage;

@end
