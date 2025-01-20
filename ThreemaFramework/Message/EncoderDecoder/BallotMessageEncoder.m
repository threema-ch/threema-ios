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

#import "BallotMessageEncoder.h"
#import "BallotChoice.h"
#import "BallotMessage.h"
#import "BallotKeys.h"
#import "MyIdentityStore.h"
#import "JsonUtil.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation BallotMessageEncoder

+ (BoxBallotVoteMessage *)encodeVoteMessageForBallot:(Ballot *)ballot {
    
    NSData *jsonData = [self jsonVoteDataFor:ballot];

    BoxBallotVoteMessage *voteMessage = [[BoxBallotVoteMessage alloc] init];
    voteMessage.messageId = [AbstractMessage randomMessageId];
    voteMessage.date = [NSDate date];
    voteMessage.ballotCreator = ballot.creatorId;
    voteMessage.ballotId = ballot.id;
    voteMessage.jsonChoiceData = jsonData;

    return voteMessage;
}

+ (BoxBallotCreateMessage *)encodeCreateMessageForBallot:(Ballot *)ballot {
    NSData *jsonData = [self jsonCreateDataFor:ballot];
    
    BoxBallotCreateMessage *boxMessage = [[BoxBallotCreateMessage alloc] init];
    boxMessage.messageId = [AbstractMessage randomMessageId];
    boxMessage.date = [NSDate date];
    boxMessage.ballotId = ballot.id;
    boxMessage.jsonData = jsonData;
    
    return boxMessage;
}

+ (NSData *)jsonCreateDataFor:(Ballot *)ballot {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    [dictionary setObject:ballot.title forKey:JSON_KEY_TITLE];
    [dictionary setObject:ballot.type forKey:JSON_KEY_TYPE];
    [dictionary setObject:ballot.state forKey:JSON_KEY_STATE];
    [dictionary setObject:ballot.assessmentType forKey:JSON_KEY_ASSESSMENT_TYPE];
    [dictionary setObject:ballot.choicesType forKey:JSON_KEY_CHOICES_TYPE];
    // Clients must no be able to set this other than 0, which is ListMode
    [dictionary setObject:[[NSNumber alloc] initWithInteger: BallotDisplayModeList] forKey:JSON_KEY_DISPLAYMODE];

    NSArray *participantArray = nil;
    if ([ballot displayResult]) {
        NSSet *participants = [self participantsForBallot:ballot];
        participantArray = [participants allObjects];
        [dictionary setObject:participantArray forKey:JSON_KEY_PARTICIPANTS];
    }

    NSArray *choices = [self choiceDataForBallot:ballot participants:participantArray];
    [dictionary setObject:choices forKey:JSON_KEY_CHOICES];
    
    NSError *error;
    NSData *jsonData = [JsonUtil serializeJsonFrom:dictionary error:error];
    if (jsonData == nil) {
        DDLogError(@"Error encoding ballot json data %@, %@", error, [error userInfo]);
    }
    
    return jsonData;
}

+ (NSArray *)choiceDataForBallot:(Ballot *)ballot participants:(NSArray *)participants {
    NSMutableArray *choiceData = [NSMutableArray array];
    
    for (BallotChoice *choice in ballot.choices) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        
        [dictionary setObject:choice.id forKey:JSON_CHOICE_KEY_ID];
        [dictionary setObject:choice.name forKey:JSON_CHOICE_KEY_NAME];
        [dictionary setObject:choice.orderPosition forKey:JSON_CHOICE_KEY_ORDER_POSITION];
        // This should always be 0, it is only be set by Broadcast
        [dictionary setObject:@0 forKey:JSON_CHOICE_KEY_TOTALVOTES];
        
        if ([ballot displayResult]) {
            NSArray *result = [self resultForChoice:choice participants:participants];
            [dictionary setObject:result forKey:JSON_CHOICE_KEY_RESULT];
        }
        
        [choiceData addObject: dictionary];
    }
    
    return choiceData;
}

+ (NSArray *)resultForChoice:(BallotChoice *)choice participants:(NSArray *)participants {
    NSMutableArray *resultArray = [NSMutableArray array];

    for (NSString *participantId in participants) {
        BallotResultEntity *result = [choice getResultForId:participantId];
        if (result) {
            [resultArray addObject: result.value];
        } else {
            DDLogError(@"missing ballot result");
            [resultArray addObject: [NSNumber numberWithInt: 0]];
        }
    }
    
    return resultArray;
}

+ (NSData *)jsonVoteDataFor:(Ballot *)ballot {
    NSMutableArray *choiceArray = [NSMutableArray array];
    for (BallotChoice *choice in ballot.choices) {
        
        NSMutableArray *resultArray = [NSMutableArray array];
        
        BallotResultEntity *ownResult = [choice getOwnResult];
        if (ownResult) {
            [resultArray addObject: choice.id];
            [resultArray addObject: ownResult.value];
            
            [choiceArray addObject: resultArray];
        }
    }

    NSError *error;
    NSData *jsonData = [JsonUtil serializeJsonFrom:choiceArray error:error];

    if (jsonData == nil) {
        DDLogError(@"Error encoding ballot vote json data %@, %@", error, [error userInfo]);
    }
    
    return jsonData;
}

+ (NSSet *)participantsForBallot:(Ballot *)ballot {
    NSMutableSet *participants = [NSMutableSet set];
    
    for (BallotChoice *choice in ballot.choices) {
        for (BallotResultEntity *result in choice.result) {
            [participants addObject: result.participantId];
        }
    }

    return participants;
}

#pragma mark - private methods

+ (GroupBallotCreateMessage*)groupBallotCreateMessageFrom:(BoxBallotCreateMessage*)boxBallotMessage groupID:(NSData*)groupID groupCreatorIdentity:(NSString*)groupCreatorIdentity {
    GroupBallotCreateMessage *msg = [[GroupBallotCreateMessage alloc] init];
    msg.messageId = boxBallotMessage.messageId;
    msg.date = boxBallotMessage.date;
    msg.groupId = groupID;
    msg.groupCreator = groupCreatorIdentity;
    msg.jsonData = boxBallotMessage.jsonData;
    msg.ballotId = boxBallotMessage.ballotId;
    return msg;
}

+ (GroupBallotVoteMessage*)groupBallotVoteMessageFrom:(BoxBallotVoteMessage*)boxBallotMessage groupID:(NSData*)groupID groupCreatorIdentity:(NSString*)groupCreatorIdentity {
    GroupBallotVoteMessage *msg = [[GroupBallotVoteMessage alloc] init];
    msg.messageId = boxBallotMessage.messageId;
    msg.date = boxBallotMessage.date;
    msg.groupId = groupID;
    msg.groupCreator = groupCreatorIdentity;
    msg.ballotCreator = boxBallotMessage.ballotCreator;
    msg.ballotId = boxBallotMessage.ballotId;
    msg.jsonChoiceData = boxBallotMessage.jsonChoiceData;
    return msg;
}

/// Checks whether the given ballot passes a basic sanity check and can be encoded
/// @param ballot The ballot that should be checked for sanity
+ (BOOL)passesSanityCheck:(nullable Ballot *) ballot {
    if (ballot == nil) {
        DDLogError(@"Ballot is nil.");
        return false;
    }
    
    if (ballot.title == nil) {
        DDLogError(@"Ballot Title is nil");
        return false;
    }
    if (ballot.type == nil) {
        DDLogError(@"Ballot Type is nil");
        return false;
    }
    if (ballot.state == nil) {
        DDLogError(@"Ballot State is nil");
        return false;
    }
    if (ballot.assessmentType == nil) {
        DDLogError(@"Ballot AssessmentType is nil");
        return false;
    }
    if (ballot.choicesType == nil) {
        DDLogError(@"Ballot ChoicesType is nil");
        return false;
    }
    
    return true;
}

@end
