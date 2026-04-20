#import <Foundation/Foundation.h>
#import <ThreemaFramework/BoxBallotCreateMessage.h>
#import <ThreemaFramework/BoxBallotVoteMessage.h>
#import <ThreemaFramework/GroupBallotCreateMessage.h>
#import <ThreemaFramework/GroupBallotVoteMessage.h>

NS_ASSUME_NONNULL_BEGIN

@interface BallotMessageEncoder : NSObject

/**
 Encode or get abstract ballot create messge of ballot entity.

 @param ballotEntityObject Object of type `BallotEntity`
 @return `BoxBallotCreateMessage`
 */
+ (BoxBallotCreateMessage *)encodeCreateMessageForBallot:(NSObject *)ballotEntityObject;

/**
 Encode or get abstract ballot vote messge of ballot entity.

 @param ballotEntityObject Object of type `BallotEntity`
 @return `BoxBallotVoteMessage`
 */
+ (BoxBallotVoteMessage *)encodeVoteMessageForBallot:(NSObject *)ballotEntityObject;

+ (GroupBallotCreateMessage*)groupBallotCreateMessageFrom:(BoxBallotCreateMessage*)boxBallotMessage groupID:(NSData*)groupID groupCreatorIdentity:(NSString*)groupCreatorIdentity;

+ (GroupBallotVoteMessage*)groupBallotVoteMessageFrom:(BoxBallotVoteMessage*)boxBallotMessage groupID:(NSData*)groupID groupCreatorIdentity:(NSString*)groupCreatorIdentity;

+ (BOOL)passesSanityCheck:(nullable NSObject *) ballotEntityObject;

@end

NS_ASSUME_NONNULL_END
