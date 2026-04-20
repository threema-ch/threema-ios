#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupFileMessage : AbstractGroupMessage <NSSecureCoding>

@property NSData *jsonData;

@end
