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

#import "BallotManager.h"
#import "MyIdentityStore.h"
#import "Ballot.h"
#import "BallotChoice.h"
#import "Contact.h"
#import "ProtocolDefines.h"

@interface BallotManager ()

@property EntityManager *entityManager;

@end

@implementation BallotManager

+ (instancetype)ballotManagerWithEntityManager:(EntityManager *)entityManager {
    BallotManager *ballotManager = [[BallotManager alloc] init];
    
    ballotManager.entityManager = entityManager;

    return ballotManager;
}

- (void)updateBallot:(Ballot *)ballot choiceId:(NSNumber *)choiceId withResult:(NSNumber *)value forContact:(NSString *)contactId {
    BallotChoice *choice = [_entityManager.entityFetcher ballotChoiceForBallotId:ballot.id choiceId:choiceId];
    
    [self updateChoice:choice withResult:value forContact:contactId];
}

- (void)updateChoice:(BallotChoice *)choice withOwnResult:(NSNumber *)value {
    NSString *contact = [MyIdentityStore sharedMyIdentityStore].identity;

    [self updateChoice:choice withResult:value forContact: contact];
}

- (void)updateChoice:(BallotChoice *)choice withResult:(NSNumber *)value forContact:(NSString *)contactId {
    BallotResult *result = [choice getResultForId:contactId];
    if (result) {
        result.value = value;
        result.modifyDate = [NSDate date];
    } else {
        result = [_entityManager.entityCreator ballotResult];
        result.value = value;
        result.participantId = contactId;
        
        [choice addResultObject: result];
    }
    
    choice.modifyDate = [NSDate date];
}

@end
