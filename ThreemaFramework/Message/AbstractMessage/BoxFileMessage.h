#import <ThreemaFramework/AbstractMessage.h>

@interface BoxFileMessage : AbstractMessage <NSSecureCoding>

@property NSData *jsonData;

@end
