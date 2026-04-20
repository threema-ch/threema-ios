#import <ThreemaFramework/AbstractMessage.h>

@interface BoxAudioMessage : AbstractMessage <NSSecureCoding>

@property (nonatomic, readwrite) uint16_t duration;
@property (nonatomic, strong) NSData *audioBlobId NS_SWIFT_NAME(audioBlobID);
@property (nonatomic, readwrite) uint32_t audioSize;
@property (nonatomic, strong) NSData *encryptionKey;

@end
