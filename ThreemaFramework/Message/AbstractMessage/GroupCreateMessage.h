#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupCreateMessage : AbstractGroupMessage <NSSecureCoding>

@property (nonatomic) NSArray *groupMembers;

@end
