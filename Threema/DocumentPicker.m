//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "DocumentPicker.h"
#import "UTIConverter.h"
#import "ModalPresenter.h"
#import "BundleUtil.h"
#import "MBProgressHUD.h"
#import "FeatureMaskChecker.h"
#import "ContactUtil.h"
#import "FileMessageSender.h"
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface DocumentPicker () <UIDocumentPickerDelegate, UIDocumentMenuDelegate, UploadProgressDelegate, CNContactPickerDelegate>

@property UIViewController *presentingViewController;
@property Conversation *conversation;

@end

@implementation DocumentPicker

static DocumentPicker *pickerStrongReference;

+ (instancetype)documentPickerForViewController:(UIViewController *)presentingViewController conversation:(Conversation *)conversation {
    DocumentPicker *picker = [[DocumentPicker alloc] init];
    picker.presentingViewController = presentingViewController;
    picker.conversation = conversation;
    
    return picker;
}

- (void)show {
    NSSet *conversations = [NSSet setWithObject:_conversation];
    
    FeatureMaskChecker *featureMaskChecker = [[FeatureMaskChecker alloc] init];
    [featureMaskChecker checkFileTransferFor:conversations presentAlarmOn:_presentingViewController onSuccess:^{
        [self showPicker];
    } onFailure:^{
        ;//nop
    }];
}

- (void)showPicker {
    NSArray *types = @[UTTYPE_ITEM, UTTYPE_DATA, UTTYPE_CONTENT, UTTYPE_ARCHIVE, UTTYPE_CONTACT, UTTYPE_MESSAGE];
    
    UIDocumentMenuViewController *controller = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
    controller.delegate = self;

    NSString *title = [BundleUtil localizedStringForKey:@"contacts"];
    UIImage *image = [BundleUtil imageNamed:@"ThumbBusinessContact.png"];
    [controller addOptionWithTitle:title image:image order:UIDocumentMenuOrderFirst handler:^{
        [self checkPermissionAndShowContactPicker];
    }];
    
    pickerStrongReference = self;
        
    [self showController:controller];
}

- (void)showController:(UIViewController *)controller {
    if (CGRectIsNull(_popoverSourceRect)) {
        [ModalPresenter present:controller on:_presentingViewController];
    } else {
        [ModalPresenter present:controller on:_presentingViewController fromRect:_popoverSourceRect inView:_presentingViewController.view];
    }
}

- (void)checkPermissionAndShowContactPicker {
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] == CNAuthorizationStatusAuthorized) {
        [self showContactPicker];
    }
    else if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] == CNAuthorizationStatusDenied) {
        [self showContactAlert];
    }
    else {
        CNContactStore *cnAddressBook = [CNContactStore new];
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) {
                [self showContactPicker];
            } else {
                [self showContactAlert];
            }
        }];
    }
}

- (void)showContactPicker {
    CNContactPickerViewController *picker = [[CNContactPickerViewController alloc] init];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self showController:picker];
}

- (void)showContactAlert {
    NSString *title = NSLocalizedString(@"no_contacts_permission_title", nil);
    NSString *message = NSLocalizedString(@"no_contacts_permission_message", nil);
    
    [self showAlertWithTitle:title message:message closeOnOk:YES];
}

- (void)sendItem:(URLSenderItem *)item {
    NSString *messageFormat = NSLocalizedString(@"send_file_message", nil);
    NSString *message = [NSString stringWithFormat:messageFormat, [item getName], _conversation.displayName];
    NSString *title = NSLocalizedString(@"send_file_title", nil);
    __block UITextField *captionTextField = nil;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        if (@available(iOS 13.0, *)) {
            textField.textColor = [Colors fontNormal];
        }
        textField.placeholder = [BundleUtil localizedStringForKey:@"optional_caption"];
        captionTextField = textField;
    }];
    NSString *ok = [BundleUtil localizedStringForKey:@"ok"];
    NSString *cancel = [BundleUtil localizedStringForKey:@"cancel"];
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:ok style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [MBProgressHUD showHUDAddedTo:_presentingViewController.view animated:YES];
        
        if (captionTextField.text.length > 0) {
            item.caption = captionTextField.text;
        }

        FileMessageSender *sender = [[FileMessageSender alloc] init];
        sender.uploadProgressDelegate = self;
        [sender sendItem:item inConversation:_conversation];
    }];
    [alertController addAction:defaultAction];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        pickerStrongReference = nil;
    }];
    [alertController addAction:cancelAction];
    
    [_presentingViewController presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    URLSenderItem *item = [URLSenderItemCreator getSenderItemFor:url];
    [self sendItem:item];
}

#pragma mark - UIDocumentMenuDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
    documentPicker.delegate = self;
    
    [self showController:documentPicker];
}

#pragma mark - UploadProgressDelegate

- (BOOL)blobMessageSenderUploadShouldCancel:(BlobMessageSender *)blobMessageSender {
    return NO;
}

- (void)blobMessageSender:(BlobMessageSender *)blobMessageSender uploadProgress:(NSNumber *)progress forMessage:(BaseMessage *)message {
    // hide as soon as progress starts which is visible in message bubble
    [MBProgressHUD hideHUDForView:_presentingViewController.view animated:YES];
}

- (void)blobMessageSender:(BlobMessageSender *)blobMessageSender uploadFailedForMessage:(BaseMessage *)message error:(UploadError)error {
    [MBProgressHUD hideHUDForView:_presentingViewController.view animated:YES];
    
    NSString *errorTitle = [BundleUtil localizedStringForKey:@"error_sending_failed"];
    NSString *errorMessage = [FileMessageSender messageForError:error];
    [self showAlertWithTitle:errorTitle message:errorMessage closeOnOk:NO];
}

- (void)blobMessageSender:(BlobMessageSender *)blobMessageSender uploadSucceededForMessage:(BaseMessage *)message {
    pickerStrongReference = nil;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message closeOnOk:(BOOL)closeOnOk {
    [UIAlertTemplate showAlertWithOwner:_presentingViewController title:title message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
        pickerStrongReference = nil;
    }];
}


#pragma mark - People picker delegate

-(void) contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact{
    NSData *vCardData = [ContactUtil vCardDataForCnContact:contact];
    URLSenderItem *item = [URLSenderItem itemWithData:vCardData fileName:nil type:UTTYPE_VCARD renderType:@0 sendAsFile:true];
    
    [picker dismissViewControllerAnimated:YES completion:^{
        [self sendItem:item];
    }];
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty  {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

-(void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
