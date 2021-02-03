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

#import "Ballot.h"
#import "BallotChoice.h"
#import "Conversation.h"
#import "MyIdentityStore.h"

@implementation Ballot

@dynamic assessmentType;
@dynamic choicesType;
@dynamic createDate;
@dynamic creatorId;
@dynamic title;
@dynamic id;
@dynamic modifyDate;
@dynamic state;
@dynamic type;
@dynamic unreadUpdateCount;
@dynamic choices;
@dynamic conversation;
@dynamic message;
@dynamic participants;

static NSArray *orderSortDescriptors;

- (NSSet *)participants {
    //ignore core data participants field, use conversation participants instead
    return [self conversationParticipants];
}

- (NSInteger)participantCount {
    //participants only contains other contacts
    return [self.participants count] + 1;
}

- (void)setupSortDescriptors {
    if (orderSortDescriptors == nil) {
        NSSortDescriptor *orderSort = [NSSortDescriptor sortDescriptorWithKey:@"orderPosition" ascending:YES];
    
        orderSortDescriptors = [NSArray arrayWithObject: orderSort];
    }
}

- (NSArray *)choicesSortedByOrder {
    [self setupSortDescriptors];
    
    return [self.choices sortedArrayUsingDescriptors: orderSortDescriptors];
}

- (void)setClosed {
    self.state = [NSNumber numberWithInt: kBallotStateClosed];
    self.modifyDate = [NSDate date];
}

- (void)setMultipleChoice:(BOOL)multipleChoice {
    if (multipleChoice) {
        self.assessmentType = [NSNumber numberWithInt: kBallotAssessmentTypeMultiple];
    } else {
        self.assessmentType = [NSNumber numberWithInt: kBallotAssessmentTypeSingle];
    }
}

- (void)setIntermediate:(BOOL)intermediate {
    if (intermediate) {
        self.type = [NSNumber numberWithInt: kBallotTypeIntermediate];
    } else {
        self.type = [NSNumber numberWithInt: kBallotTypeClosed];
    }
}

- (BOOL)isClosed {
    return self.state.intValue == kBallotStateClosed;
}

- (BOOL)isMultipleChoice {
    return self.assessmentType.intValue == kBallotAssessmentTypeMultiple;
}

- (BOOL)isIntermediate {
    return self.type.intValue == kBallotTypeIntermediate;
}

- (BOOL)displayResult {
    return [self isIntermediate] || [self isClosed];
}

- (BOOL)isOwn {
    return [self.creatorId isEqualToString: [MyIdentityStore sharedMyIdentityStore].identity];
}

- (BOOL)canEdit {
    return [self isOwn] && [self isClosed] == NO;
}

- (void)incrementUnreadUpdateCount {
    NSInteger currentValue = [self.unreadUpdateCount integerValue];
    self.unreadUpdateCount = [NSNumber numberWithInteger: currentValue++];
}

- (void)resetUnreadUpdateCount {
    self.unreadUpdateCount = [NSNumber numberWithInteger: 0];
}

- (NSSet *)conversationParticipants {
    if (self.conversation) {
        return self.conversation.participants;
    } else {
        return nil;
    }
}

- (NSSet *)ballotParticipants {
    NSMutableSet *set = [NSMutableSet set];
    for (BallotChoice *choice in self.choices) {
        NSSet *participantsForChoice = [choice getAllParticipantIds];
        [set unionSet:participantsForChoice];
    }
    
    return set;
}

- (NSInteger)numberOfReceivedVotes {
    NSSet *set = [self ballotParticipants];
    
    return [set count];
}
@end
