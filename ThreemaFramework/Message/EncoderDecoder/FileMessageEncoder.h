#import <Foundation/Foundation.h>
#import <ThreemaFramework/BoxFileMessage.h>
#import <ThreemaFramework/GroupFileMessage.h>

@interface FileMessageEncoder : NSObject

/**
 Encode or get abstract file message of file entity.

 @param fileMessageEntityObject Object of type `FileMessageEntity`
 @return `BoxFileMessage`
 */
+ (BoxFileMessage *)encodeFileMessageEntity:(nonnull NSObject *)fileMessageEntityObject NS_SWIFT_NAME(encodeFileMessageEntity(_:));

/**
 Encode or get abstract group file message of file entity.

 @param fileMessageEntityObject Object of type `FileMessageEntity`
 @return `GroupFileMessage`
 */
+ (GroupFileMessage *)encodeGroupFileMessageEntity:(nonnull NSObject *)fileMessageEntityObject;

/**
 @param fileMessageEntityObject Object of type `FileMessageEntity`
 @return `NSString`
 */
+ (NSString *)jsonStringForFileMessageEntity:(nonnull NSObject *)fileMessageEntityObject NS_SWIFT_NAME(jsonString(for:));

@end
