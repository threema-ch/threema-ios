#import <ThreemaFramework/AbstractMessage.h>

@interface AbstractGroupMessage : AbstractMessage <NSSecureCoding>

@property (nonatomic, strong) NSString *groupCreator;
@property (nonatomic, strong) NSData *groupId NS_SWIFT_NAME(groupID);

- (BOOL)isGroupControlMessage;
- (BOOL)isGroupCallMessage;

@end
