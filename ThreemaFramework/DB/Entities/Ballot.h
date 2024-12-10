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
#import <CoreData/CoreData.h>

#import <ThreemaFramework/TMAManagedObject.h>

typedef NS_ENUM(NSInteger, BallotDisplayMode) {
    BallotDisplayModeList = 0,
    BallotDisplayModeSummary = 1,
};


@class ContactEntity,BallotChoice, BallotMessage, ConversationEntity;

@interface Ballot : TMAManagedObject

// Attributes
@property (nonatomic, retain) NSNumber * assessmentType;
@property (nonatomic, retain) NSNumber * choicesType;
@property (nonatomic, retain) NSDate * createDate;
@property (nonatomic, retain) NSString * creatorId NS_SWIFT_NAME(creatorID);
@property (nonatomic) BallotDisplayMode ballotDisplayMode;
@property (nonatomic, retain) NSData * id;
@property (nonatomic, retain) NSDate * modifyDate;
@property (nonatomic, retain) NSNumber * state;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * type;

// Relationships
@property (nonatomic, retain) NSSet *choices;
@property (nonatomic, retain) ConversationEntity *conversation;
@property (nonatomic, retain) NSSet *message;
// Participants are persisted once the ballot is closed
@property (nonatomic, retain) NSSet *participants;
@end

@interface Ballot (CoreDataGeneratedAccessors)

- (void)addChoicesObject:(BallotChoice *)value;
- (void)removeChoicesObject:(BallotChoice *)value;
- (void)addChoices:(NSSet *)values;
- (void)removeChoices:(NSSet *)values;

- (void)addMessageObject:(BallotMessage *)value;
- (void)removeMessageObject:(BallotMessage *)value;
- (void)addMessage:(NSSet *)values;
- (void)removeMessage:(NSSet *)values;

- (void)addParticipantsObject:(ContactEntity *)value;
- (void)removeParticipantsObject:(ContactEntity *)value;
- (void)addParticipants:(NSSet *)values;
- (void)removeParticipants:(NSSet *)values;

- (BallotDisplayMode)ballotDisplayMode;
- (void)setBallotDisplayMode:(BallotDisplayMode)ballotDisplayMode;
#pragma mark - Own Definitions & Methods

enum {
    kBallotStateOpen = 0,
    kBallotStateClosed
};

enum {
    kBallotTypeClosed = 0,
    kBallotTypeIntermediate
};

enum {
    kBallotAssessmentTypeSingle = 0,
    kBallotAssessmentTypeMultiple
};

- (NSArray *)choicesSortedByOrder;

- (void)setClosed;

- (void)setMultipleChoice:(BOOL)multipleChoice;

- (void)setIntermediate:(BOOL)intermediate;

- (BOOL)isClosed;

- (BOOL)isMultipleChoice;

- (BOOL)isIntermediate;

- (BOOL)displayResult;

- (BOOL)isOwn;

- (BOOL)canEdit;

- (NSInteger)numberOfReceivedVotes;

- (NSInteger)participantCount;

- (NSInteger)conversationParticipantsCount;

- (BOOL)localIdentityDidVote;

- (BOOL)hasVotesForIdentity:(NSString *)identity;

- (NSSet*)voters;

- (NSSet*)nonVoters;

- (NSMutableArray*)mostVotedChoices;
@end
