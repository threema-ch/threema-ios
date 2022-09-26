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

#import "GroupBallotVoteMessage.h"
#import "ProtocolDefines.h"

@implementation GroupBallotVoteMessage

- (uint8_t)type {
    return MSGTYPE_GROUP_BALLOT_VOTE;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:[self.groupCreator dataUsingEncoding:NSASCIIStringEncoding]];
    [body appendData:self.groupId];
    [body appendData:[_ballotCreator dataUsingEncoding:NSASCIIStringEncoding]];
    [body appendData:_ballotId];
    [body appendData:_jsonChoiceData];
    
    return body;
}

- (BOOL)shouldPush {
    return NO;
}

-(BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.ballotCreator = [decoder decodeObjectForKey:@"ballotCreator"];
        self.ballotId = [decoder decodeObjectForKey:@"ballotId"];
        self.jsonChoiceData = [decoder decodeObjectForKey:@"jsonChoiceData"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.ballotCreator forKey:@"ballotCreator"];
    [encoder encodeObject:self.ballotId forKey:@"ballotId"];
    [encoder encodeObject:self.jsonChoiceData forKey:@"jsonChoiceData"];
}

@end
