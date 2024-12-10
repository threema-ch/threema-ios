//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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
#import <ThreemaFramework/Ballot.h>

@class BallotResultEntity;

NS_ASSUME_NONNULL_BEGIN

@interface BallotMessageEncoder : NSObject

+ (BoxBallotCreateMessage *)encodeCreateMessageForBallot:(Ballot *)ballot;

+ (BoxBallotVoteMessage *)encodeVoteMessageForBallot:(Ballot *)ballot;

+ (GroupBallotCreateMessage*)groupBallotCreateMessageFrom:(BoxBallotCreateMessage*)boxBallotMessage groupID:(NSData*)groupID groupCreatorIdentity:(NSString*)groupCreatorIdentity;

+ (GroupBallotVoteMessage*)groupBallotVoteMessageFrom:(BoxBallotVoteMessage*)boxBallotMessage groupID:(NSData*)groupID groupCreatorIdentity:(NSString*)groupCreatorIdentity;

+ (BOOL)passesSanityCheck:(nullable Ballot *) ballot;

@end

NS_ASSUME_NONNULL_END
