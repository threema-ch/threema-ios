#import <ThreemaFramework/AbstractMessage.h>

@interface BoxBallotVoteMessage : AbstractMessage <NSSecureCoding>

@property NSString *ballotCreator;
@property NSData *ballotId NS_SWIFT_NAME(ballotID);
@property NSData *jsonChoiceData;

@end
