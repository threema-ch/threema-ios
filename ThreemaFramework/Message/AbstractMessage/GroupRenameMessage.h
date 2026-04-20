#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupRenameMessage : AbstractGroupMessage <NSSecureCoding>

@property (nonatomic, strong) NSString *name;

@end
