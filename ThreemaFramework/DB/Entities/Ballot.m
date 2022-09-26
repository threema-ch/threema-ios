//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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
#import "Contact.h"
#import "MyIdentityStore.h"

static NSString *fieldDisplayMode = @"displayMode";

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

- (BOOL)isClosed {
    return self.state.intValue == kBallotStateClosed;
}

- (void)setMultipleChoice:(BOOL)multipleChoice {
    if (multipleChoice) {
        self.assessmentType = [NSNumber numberWithInt: kBallotAssessmentTypeMultiple];
    } else {
        self.assessmentType = [NSNumber numberWithInt: kBallotAssessmentTypeSingle];
    }
}

- (BOOL)isMultipleChoice {
    return self.assessmentType.intValue == kBallotAssessmentTypeMultiple;
}

- (void)setIntermediate:(BOOL)intermediate {
    if (intermediate) {
        self.type = [NSNumber numberWithInt: kBallotTypeIntermediate];
    } else {
        self.type = [NSNumber numberWithInt: kBallotTypeClosed];
    }
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

- (NSInteger)conversationParticipantsCount {
    if (self.conversation) {
        return self.conversation.participants.count + 1;
    } else {
        return 0;
    }
}

- (NSInteger)numberOfReceivedVotes {
    NSMutableSet *set = [NSMutableSet set];

    for (BallotChoice *choice in self.choices) {
        NSSet *participantsForChoice = [choice getAllParticipantIds];
        [set unionSet:participantsForChoice];
    }
    return [set count];
}

- (BOOL)localIdentityDidVote {
    NSMutableSet *idSet = [NSMutableSet set];

    for (BallotChoice *choice in self.choices) {
        NSSet *participantsForChoice = [choice getAllParticipantIds];
        [idSet unionSet:participantsForChoice];
    }
    return [idSet containsObject: [MyIdentityStore sharedMyIdentityStore].identity];
}

/// Returns set of contacts that did vote, does not include local user
- (NSSet *)voters {
    NSMutableSet *idSet = [NSMutableSet set];
    NSMutableSet *contactSet = [NSMutableSet set];

    for (BallotChoice *choice in self.choices) {
        NSSet *participantsForChoice = [choice getAllParticipantIds];
        [idSet unionSet:participantsForChoice];
    }
    for (Contact *contact in self.conversation.participants) {
        if([idSet containsObject: contact.identity]) {
            [contactSet addObject:contact];
        }
    }
    
    return contactSet;
}

/// Returns set of contacts that did not vote, does not include local user
- (NSSet *)nonVoters {
    NSMutableSet *idSet = [NSMutableSet set];
    NSMutableSet *contactSet = [NSMutableSet set];

    for (BallotChoice *choice in self.choices) {
        NSSet *participantsForChoice = [choice getAllParticipantIds];
        [idSet unionSet:participantsForChoice];
    }
    for (Contact* contact in self.conversation.participants) {
        if(![idSet containsObject:contact.identity]) {
            [contactSet addObject:contact];
        }
    }
    
    return contactSet;
}

- (BallotDisplayMode)ballotDisplayMode {
    if ([self valueForKey:fieldDisplayMode] != nil) {
        switch ([[self valueForKey:fieldDisplayMode] intValue]) {
            case BallotDisplayModeSummary:
                return BallotDisplayModeSummary;
            default:
                return BallotDisplayModeList;
        }
    }
    return BallotDisplayModeList;
}

- (void)setBallotDisplayMode:(BallotDisplayMode)ballotDisplayMode {
    [self willChangeValueForKey:fieldDisplayMode];
    [self setPrimitiveValue:[NSNumber numberWithInt:(int)ballotDisplayMode] forKey:fieldDisplayMode];
    [self didChangeValueForKey:fieldDisplayMode];
}

- (NSMutableArray*)mostVotedChoices {
    NSMutableArray* mostVoted = [[NSMutableArray alloc] init];
    NSInteger highest = 0;
    
    for (BallotChoice *choice in self.choicesSortedByOrder) {
        if (choice.totalCountOfResultsTrue == 0) {
            continue;
        }
        
        if (choice.totalCountOfResultsTrue == highest) {
            [mostVoted addObject:[NSString stringWithString:choice.name]];
            continue;
        }
        
        if (choice.totalCountOfResultsTrue > highest) {
            highest = choice.totalCountOfResultsTrue;
            [mostVoted removeAllObjects];
            [mostVoted addObject:[NSString stringWithString:choice.name]];
        }
    }
    return mostVoted;
}

@end
