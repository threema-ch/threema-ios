#import "GroupBallotVoteMessage.h"
#import "ProtocolDefines.h"
#import "NSString+Hex.h"

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

- (BOOL)flagShouldPush {
    return NO;
}

-(BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

- (BOOL)canShowUserNotification {
    return NO;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV12;
}

#pragma mark - LoggingDescriptionProtocol

- (NSString * _Nonnull)loggingDescription {
    return [NSString stringWithFormat:@"(%@ ballotID: %@)",
            [super loggingDescription],
            [NSString stringWithHexData:self.ballotId]];
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.ballotCreator = [decoder decodeObjectOfClass:[NSString class] forKey:@"ballotCreator"];
        self.ballotId = [decoder decodeObjectOfClass:[NSData class] forKey:@"ballotId"];
        self.jsonChoiceData = [decoder decodeObjectOfClass:[NSData class] forKey:@"jsonChoiceData"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.ballotCreator forKey:@"ballotCreator"];
    [encoder encodeObject:self.ballotId forKey:@"ballotId"];
    [encoder encodeObject:self.jsonChoiceData forKey:@"jsonChoiceData"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
