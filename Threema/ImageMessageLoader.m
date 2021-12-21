//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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
#import "ImageMessage.h"
#import "ImageData.h"
#import "MyIdentityStore.h"
#import "ProtocolDefines.h"
#import "NaClCrypto.h"
#import "MessageSender.h"
#import "EntityManager.h"
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

- (NSData *)decryptData:(NSData *)data {
    NSData *decryptedData = nil;
    
    @try {
        NSData *encryptionKey = [self.message blobGetEncryptionKey];
        if (encryptionKey != nil) {
            decryptedData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
        } else {
            NSData *imageNonce = ((ImageMessage *)self.message).imageNonce;
            NSData *publicKey = self.message.conversation.contact.publicKey;
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

- (void)updateDBObjectWithData:(NSData *)data onCompletion:(void(^)(void))onCompletion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *thumbnail = [MediaConverter getThumbnailForImage:_image];
        
        NSData *thumbnailData = UIImageJPEGRepresentation(thumbnail, kJPEGCompressionQualityLow);
        
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            ImageMessage *imageMessage = (ImageMessage *)self.message;
            
            [imageMessage blobSetData:data];
            
            imageMessage.sendFailed = [NSNumber numberWithBool:NO];
            [imageMessage blobUpdateProgress:nil];
            
            ImageData *dbThumbnail = [entityManager.entityCreator imageData];
            dbThumbnail.data = thumbnailData;
            dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
            dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
            
            imageMessage.thumbnail = dbThumbnail;
        }];
        
        /* Add to photo library */
        if ([UserSettings sharedUserSettings].autoSaveMedia) {
            [[AlbumManager shared] saveWithImage:_image];
        }
        onCompletion();
    });
}

@end
