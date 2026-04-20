#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupBallotCreateMessage : AbstractGroupMessage <NSSecureCoding>

@property NSData *ballotId NS_SWIFT_NAME(ballotID);
@property NSData *jsonData;

@end
