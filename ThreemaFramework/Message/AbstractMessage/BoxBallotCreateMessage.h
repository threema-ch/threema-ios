#import <ThreemaFramework/AbstractMessage.h>

@interface BoxBallotCreateMessage : AbstractMessage <NSSecureCoding>

@property NSData *ballotId NS_SWIFT_NAME(ballotID);
@property NSData *jsonData;

@end
