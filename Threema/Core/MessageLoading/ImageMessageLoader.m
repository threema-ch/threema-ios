//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "ImageMessageLoader.h"
#import "ImageMessageEntity.h"
#import "ImageData.h"
#import "MyIdentityStore.h"
#import "ProtocolDefines.h"
#import "NaClCrypto.h"
#import "MessageSender.h"
#import "UserSettings.h"
#import "MediaConverter.h"
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface ImageMessageLoader ()

@property UIImage *image;

@end

@implementation ImageMessageLoader

- (NSData *)decryptData:(NSData *)data forMessage:(BaseMessage<BlobData> *)message {
    NSData *decryptedData = nil;
    
    @try {
        NSData *encryptionKey = [message blobGetEncryptionKey];
        if (encryptionKey != nil) {
            decryptedData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
        } else {
            NSData *imageNonce = ((ImageMessageEntity *)message).imageNonce;
            NSData *publicKey = message.conversation.contact.publicKey;
            decryptedData = [[MyIdentityStore sharedMyIdentityStore] decryptData:data withNonce:imageNonce publicKey:publicKey];
        }
        
        if (decryptedData) {
            _image = [UIImage imageWithData:decryptedData];
            if (_image == nil) {
                DDLogError(@"Image decoding failed");
                decryptedData = nil;
            }
        }

    } @catch (NSException *exception) {
        DDLogError(@"Image decryption failed: %@", [exception description]);
    }
    
    return decryptedData;
}

- (void)updateDBObject:(BaseMessage<BlobData> *)message with:(NSData *)data {
    if (![message isKindOfClass:ImageMessageEntity.class]) {
        return;
    }

    [super updateDBObject:message with:data];

    UIImage *thumbnail = [MediaConverter getThumbnailForImage:_image];
    if (thumbnail) {
        NSData *thumbnailData = UIImageJPEGRepresentation(thumbnail, kJPEGCompressionQualityLow);
        if (thumbnailData) {
            ImageData *dbThumbnail = [self.entityManager.entityCreator imageData];
            dbThumbnail.data = thumbnailData;
            dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
            dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];

            ((ImageMessageEntity *)message).thumbnail = dbThumbnail;
        }
    }

    /* Add to photo library */
    if ([UserSettings sharedUserSettings].autoSaveMedia && _image) {
        [[AlbumManager shared] saveWithImage:_image];
    }
}

@end
