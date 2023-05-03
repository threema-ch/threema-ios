//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "ShareController.h"
#import "AppDelegate.h"
#import "UIDefines.h"
#import "ContactGroupPickerViewController.h"
#import "BundleUtil.h"
#import "Old_FileMessageSender.h"
#import "UTIConverter.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "UserSettings.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface ShareController () <ContactGroupPickerDelegate, ModalNavigationControllerDelegate, UploadProgressDelegate>

@property NSMutableDictionary *info;

@end

@implementation ShareController

- (void)startShare {
    _info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithBool:YES], kKeyForceCompose,
             nil];
    
    if (_text) {
        [_info setObject:_text forKey:kKeyText];
    }

    if (_image) {
        [_info setObject:_image forKey:kKeyImage];
    }

    /* do we already know the target contact? */
    if (_contact != nil) {
        [self shareWithContact];
    } else {
        ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
        ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)navigationController.topViewController;
        picker.enableMultiSelection = NO;
        picker.enableTextInput = NO;
        picker.submitOnSelect = YES;
                
        [[AppDelegate sharedAppDelegate].window.rootViewController presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)shareWithContact {
    [_info setObject:_contact forKey:kKeyContact];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:_info];
}

- (void)shareWithConversation:(Conversation *)conversation renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    
    if (conversation == nil) {
        return;
    }
    
    if(_url) {
        NSSet *conversations = [NSSet setWithObject:conversation];
        
        URLSenderItem *item;
        if (sendAsFile) {
            NSString *mimetype = [UTIConverter mimeTypeFromUTI:[UTIConverter utiForFileURL:_url]];
            item = [URLSenderItem itemWithUrl:_url type:mimetype renderType:renderType sendAsFile:true];
        } else {
            item = [URLSenderItemCreator getSenderItemFor:_url];
        }
        for (Conversation *conv in conversations) {
            if ([UserSettings sharedUserSettings].newChatViewActive) {
                BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
                [manager createMessageAndSyncBlobsFor:item in:conversation correlationID:nil webRequestID:nil];
            }
            else {
                Old_FileMessageSender *sender = [[Old_FileMessageSender alloc] init];
                [sender sendItem:item inConversation:conv];
                sender.uploadProgressDelegate = self;
            }
        }
    } else {
        DDLogError(@"No URL provided, can't share anything");
    }
    
    [_info setObject:conversation forKey:kKeyConversation];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:_info];
}

- (void)deleteInboxFile {
    if ([_url.path rangeOfString:@"Documents/Inbox"].location != NSNotFound) {
        [[NSFileManager defaultManager] removeItemAtURL:_url error:nil];
    }
}

#pragma mark - Contact picker delegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {   
    [contactPicker dismissViewControllerAnimated:YES completion:^{
        // Only one expected
        Conversation *conversation = conversations.anyObject;
        [self shareWithConversation:conversation renderType:renderType sendAsFile:sendAsFile];
    }];
}

- (void)contactPickerDidCancel:(ContactGroupPickerViewController*)contactPicker {
    [contactPicker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ModalNavigationControllerDelegate

- (void)didDismissModalNavigationController {
    ;//nop
}

#pragma mark - UploadProgressDelegate

- (void)blobMessageSender:(Old_BlobMessageSender *)blobMessageSender uploadFailedForMessage:(BaseMessage *)message error:(UploadError)error {
    NSString *errorTitle = [BundleUtil localizedStringForKey:@"error_sending_failed"];
    NSString *errorMessage = [Old_FileMessageSender messageForError:error];
    
    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:errorTitle message:errorMessage actionOk:nil];    
    [self deleteInboxFile];
}

- (void)blobMessageSender:(Old_BlobMessageSender *)blobMessageSender uploadSucceededForMessage:(BaseMessage *)message {
    [self deleteInboxFile];
}

- (BOOL)blobMessageSenderUploadShouldCancel:(Old_BlobMessageSender *)blobMessageSender {
    return NO;
}

- (void)blobMessageSender:(Old_BlobMessageSender *)blobMessageSender uploadProgress:(NSNumber *)progress forMessage:(BaseMessage *)message {
    ;//nop
}

@end
