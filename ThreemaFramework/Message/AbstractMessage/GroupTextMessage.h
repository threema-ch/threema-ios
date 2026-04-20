#import <ThreemaFramework/AbstractGroupMessage.h>
#import <ThreemaFramework/QuotedMessageProtocol.h>

@interface GroupTextMessage : AbstractGroupMessage <NSSecureCoding, QuotedMessageProtocol>

@property (nonatomic, strong) NSString *text;

@end
