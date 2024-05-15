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

#import "BallotMessage.h"
#import "Ballot.h"
#import "BallotChoice.h"
#import "BundleUtil.h"

#define KEY_BALLOT @"ballot"

@implementation BallotMessage

@dynamic ballotState;
@dynamic ballot;

- (NSString*)format {
    NSString *prefix = [BundleUtil localizedStringForKey:@"ballot"];
    NSMutableString *string = [NSMutableString stringWithFormat:@"%@: %@\n", prefix, self.ballot.title];
    
    for (BallotChoice *choice in self.ballot.choicesSortedByOrder) {
        [string appendFormat:@"- %@\n", choice.name];
    }
    
    return  string;
}

- (nullable NSString*)additionalExportInfo {
    return [self format];
}

- (BOOL)isSummaryMessage {
    return self.ballotState.intValue == kBallotMessageStateCloseBallot && self.ballot.state.intValue == kBallotStateClosed;
}

- (void)setBallot:(Ballot *)ballot
{
    [self willChangeValueForKey:@"ballot"];
    [self setPrimitiveValue:ballot forKey:@"ballot"];
    
    // make sure ballot object is fresh
    [ballot.managedObjectContext refreshObject:ballot mergeChanges:YES];
    [self updateBallotState];
    
    [self didChangeValueForKey:@"ballot"];
}

- (void)updateBallotState {
    
    NSInteger messageState;
    switch (self.ballot.state.integerValue) {
        case kBallotStateOpen:
            messageState = kBallotMessageStateOpenBallot;
            break;

        case kBallotStateClosed:
            messageState = kBallotMessageStateCloseBallot;
            break;

        default:
            // ignore unexpected state
            return;
    }
    
    self.ballotState = [NSNumber numberWithInteger:messageState];
}

@end
