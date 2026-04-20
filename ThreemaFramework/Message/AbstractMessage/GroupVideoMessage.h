#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupVideoMessage : AbstractGroupMessage <NSSecureCoding>

@property (nonatomic, readwrite) uint16_t duration;
@property (nonatomic, strong) NSData *videoBlobId NS_SWIFT_NAME(videoBlobID);
@property (nonatomic, readwrite) uint32_t videoSize;
@property (nonatomic, strong) NSData *thumbnailBlobId NS_SWIFT_NAME(thumbnailBlobID);
@property (nonatomic, readwrite) uint32_t thumbnailSize;
@property (nonatomic, strong) NSData *encryptionKey;

@end
