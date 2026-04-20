#import <Foundation/Foundation.h>
#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupBallotVoteMessage : AbstractGroupMessage <NSSecureCoding>

@property NSString *ballotCreator;
@property NSData *ballotId NS_SWIFT_NAME(ballotID);
@property NSData *jsonChoiceData;

@end
