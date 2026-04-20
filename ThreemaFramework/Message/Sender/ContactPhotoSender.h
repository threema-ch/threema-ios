#import <Foundation/Foundation.h>
#import <ThreemaFramework/Old_BlobUploadDelegate.h>
#import <ThreemaFramework/AbstractMessage.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ContactPhotoSenderProtocol <NSObject>

+ (void)sendProfilePictureRequest:(NSString *)toIdentity;

/**
 Send my profile picture to the sender of the given received message if necessary.

 @param message Sender of message is receiver of profile picture
 */
- (void)sendProfilePicture:(AbstractMessage *)message NS_SWIFT_NAME(sendProfilePicture(message:));

/**
 Send photo of the contact.

 @param toMemberObject Object of type `ContactEntity`
 @param onCompletion No parameter
 @param onError With parameter of type `NSError`
 */
- (void)startWithImageToMember:(NSObject *)toMemberObject onCompletion:(void (^ _Nullable)(void))onCompletion onError:(void (^ _Nullable)(NSError * _Nullable ))onError;

@end

@interface ContactPhotoSender : NSObject <ContactPhotoSenderProtocol, Old_BlobUploadDelegate>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWith:(nonnull NSObject *)entityManagerObject;

@end

NS_ASSUME_NONNULL_END
