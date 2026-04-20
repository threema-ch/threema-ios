#import <ThreemaFramework/AbstractMessage.h>
#import <ThreemaFramework/QuotedMessageProtocol.h>

@interface BoxTextMessage : AbstractMessage <NSSecureCoding, QuotedMessageProtocol>

@property (nonatomic, strong) NSString *text;

@end
