#import <ThreemaFramework/AbstractMessage.h>
#import <ThreemaFramework/ReceiptType.h>

@interface DeliveryReceiptMessage : AbstractMessage <NSSecureCoding>

@property (nonatomic) ReceiptType receiptType;
@property (nonatomic, strong) NSArray *receiptMessageIds NS_SWIFT_NAME(receiptMessageIDs);

@end
