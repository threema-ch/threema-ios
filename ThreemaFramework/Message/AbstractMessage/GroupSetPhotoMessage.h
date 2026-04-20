#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupSetPhotoMessage : AbstractGroupMessage <NSSecureCoding>

@property (nonatomic, strong) NSData *blobId NS_SWIFT_NAME(blobID);
@property (nonatomic, readwrite) uint32_t size;
@property (nonatomic, strong) NSData *encryptionKey;

@end
