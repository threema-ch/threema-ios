#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupDeliveryReceiptMessage : AbstractGroupMessage <NSSecureCoding>

@property (nonatomic) uint8_t receiptType;
@property (nonatomic, strong) NSArray *receiptMessageIds NS_SWIFT_NAME(receiptMessageIDs);

@end
