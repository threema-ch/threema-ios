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

#import "FileMessagePreview.h"
#import "UTIConverter.h"
#import "ModalNavigationController.h"
#import "ContactUtil.h"
#import "ModalPresenter.h"
#import "ActivityUtil.h"
#import "RectUtil.h"
#import "BundleUtil.h"
#import "ImageData.h"
#import "FileMessagePreviewUnsupportedTypeView.h"
#import "UIImage+ColoredImage.h"
#import "AppDelegate.h"
#import "AppGroup.h"
#import "Utils.h"
#import "Threema-Swift.h"

#import <PassKit/PassKit.h>
#import <QuickLook/QuickLook.h>
#import "MDMSetup.h"

@interface FileMessagePreview () <ModalNavigationControllerDelegate, QLPreviewControllerDataSource, UIDocumentInteractionControllerDelegate>

@property FileMessage *fileMessage;
@property UIViewController *previewBaseController;
@property NSURL *tmpFileUrl;

@end

@implementation FileMessagePreview

+ (instancetype)fileMessagePreviewFor:(FileMessage *)fileMessage {
    FileMessagePreview *preview = [[FileMessagePreview alloc] init];
    preview.fileMessage = fileMessage;
    
    return preview;
}

+ (BOOL)shouldExportToURL:(FileMessage *)fileMessage {
    if ([fileMessage.mimeType isEqualToString:@"text/vcard"]) {
        return NO;
    }
    
    return YES;
}

+ (UIImage *)thumbnailForFileMessage:(FileMessage *)fileMessage {
    UIImage *thumbnailImage;
    if (fileMessage.thumbnail) {
        thumbnailImage = fileMessage.thumbnail.uiImage;
    }
    
    if (thumbnailImage == nil) {
        // not existing or invalid data
        thumbnailImage = [UTIConverter getDefaultThumbnailForMimeType:fileMessage.mimeType];
        
        // colorize
        thumbnailImage = [thumbnailImage imageWithTint:[Colors fontNormal]];
    }
    return thumbnailImage;
}

- (void)addShareButtonTo:(UIViewController *)viewController {
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareButtonTapped:)];
    viewController.navigationItem.rightBarButtonItem = shareButton;
}

- (ModalNavigationController *)setupNavigationControllerWithRootViewController:(UIViewController *)rootViewController {
    ModalNavigationController *navigationController = [[ModalNavigationController alloc] initWithRootViewController:rootViewController];
    navigationController.showDoneButton = YES;
    navigationController.dismissOnTapOutside = YES;
    navigationController.showFullScreenOnIPad = YES;
    return navigationController;
}

- (void)showOn:(UIViewController *)targetViewController {
    if ([UTIConverter isContactMimeType:_fileMessage.mimeType]) {
        [self checkContactAccessFor:targetViewController];
    }
    else if ([UTIConverter isAudioMimeType:_fileMessage.mimeType]) {
        MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
        if ([mdmSetup disableShareMedia] == false) {
            [self showUsingDocumentInteractionControllerOn:targetViewController];
        } else {
            [self showUsingQuickLookPreviewOn:targetViewController];
        }
    }
    else if ([UTIConverter isPassMimeType:_fileMessage.mimeType]) {
        [self showUsingAddPassesControllerOn:targetViewController];
    }
    else {
        [self showUsingQuickLookPreviewOn:targetViewController];
    }
}

- (void)checkContactAccessFor:(UIViewController *)targetViewController {
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized) {
        CNContactStore *cnAddressBook = [CNContactStore new];
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showContactOn:targetViewController];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"no_contacts_permission_title", nil) message:NSLocalizedString(@"no_contacts_permission_message", nil) actionOk:nil];
                });
            }
        }];
    } else {
        [self showContactOn:targetViewController];
    }
}

- (void)showContactOn:(UIViewController *)targetViewController {
    UIViewController *personViewController = [ContactUtil getContactViewControllerForVCardData:_fileMessage.data.data];
    _previewBaseController = [self setupNavigationControllerWithRootViewController:personViewController];
    [self addShareButtonTo:personViewController];

    [targetViewController presentViewController:_previewBaseController animated:YES completion:nil];
}

- (void)showUsingDocumentInteractionControllerOn:(UIViewController *)targetViewController {
    NSString *filename = [FileUtility getTemporarySendableFileNameWithBase:@"file"];
    _tmpFileUrl = [_fileMessage tmpURL:filename];
    [_fileMessage exportDataToURL:_tmpFileUrl];
        
    _previewBaseController = targetViewController;
    
    UIDocumentInteractionController *dc = [UIDocumentInteractionController interactionControllerWithURL:_tmpFileUrl];
    dc.delegate = self;
    
    if ([dc presentPreviewAnimated:YES] == NO) {
        [self showNoPreviewAvailableOn:targetViewController];
    }
}

- (UIViewController*)noPreviewAvailableViewController {
    UIViewController *viewController = [[UIViewController alloc] init];
    [self addThumbnailViewTo:viewController.view];
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
    if ([mdmSetup disableShareMedia] == false) {
        [self addShareButtonTo:viewController];
    }
    return viewController;
}

- (void)showNoPreviewAvailableOn:(UIViewController *)targetViewController {
    _previewBaseController = [self setupNavigationControllerWithRootViewController:[self noPreviewAvailableViewController]];
    [targetViewController presentViewController:_previewBaseController animated:YES completion:nil];
}

- (void)showUsingQuickLookPreviewOn:(UIViewController *)targetViewController {
    NSString *filename = [FileUtility getTemporarySendableFileNameWithBase:@"file"];
    _tmpFileUrl = [_fileMessage tmpURL:filename];
    [_fileMessage exportDataToURL:_tmpFileUrl];
    
    ThreemaQLPreviewController *previewController = [[ThreemaQLPreviewController alloc] init];
    previewController.dataSource = self;
    
    if (![ThreemaQLPreviewController canPreviewItem:[self previewController:previewController previewItemAtIndex:0]]) {
        [[NSFileManager defaultManager] removeItemAtURL:_tmpFileUrl error:nil];
        _tmpFileUrl = nil;
        _previewBaseController = [self setupNavigationControllerWithRootViewController:[self noPreviewAvailableViewController]];
    } else {
        ModalNavigationController *modalNavController = [self setupNavigationControllerWithRootViewController:previewController];
        modalNavController.modalDelegate = self;
        _previewBaseController = modalNavController;
    }
    
    [targetViewController presentViewController:_previewBaseController animated:YES completion:^{}];
}

- (void)showUsingAddPassesControllerOn:(UIViewController *)targetViewController {
    NSError *error = nil;
    PKPass *pass = [[PKPass alloc] initWithData:_fileMessage.data.data error:&error];
    if (pass != nil) {
        PKAddPassesViewController *addPassVc = [[PKAddPassesViewController alloc] initWithPass:pass];
        [targetViewController presentViewController:addPassVc animated:YES completion:nil];
    } else {
        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
    }
}

- (void)shareButtonTapped:(UIBarButtonItem *)sender {
    UIActivityViewController *activityViewController = [ActivityUtil activityViewControllerForMessage:_fileMessage withView:_previewBaseController.view andBarButtonItem:sender];
    NSUserDefaults *defaults = [AppGroup userDefaults];
    [defaults setDouble:[Utils systemUptime] forKey:@"UIActivityViewControllerOpenTime"];
    [defaults synchronize];
    [activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults removeObjectForKey:@"UIActivityViewControllerOpenTime"];
    }];
    [ModalPresenter present:activityViewController on:_previewBaseController fromBarButton:sender];
}

- (void)addThumbnailViewTo:(UIView *)view {
    FileMessagePreviewUnsupportedTypeView *fileView = [FileMessagePreviewUnsupportedTypeView fileMessagePreviewUnsupportedTypeView];
    fileView.fileMessage = _fileMessage;
    
    [view addSubview:fileView];
    view.backgroundColor = fileView.backgroundColor;
    
    fileView.frame = [RectUtil rect:fileView.frame centerIn:view.frame round:YES];
}

- (void)willDismissModalNavigationController {
    if (_tmpFileUrl) {
        [[NSFileManager defaultManager] removeItemAtURL:_tmpFileUrl error:nil];
        _tmpFileUrl = nil;
    }
}

#pragma mark - QLPreviewControllerDataSource

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return _tmpFileUrl;
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return _previewBaseController;
}

- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller {
    if (_tmpFileUrl) {
        [[NSFileManager defaultManager] removeItemAtURL:_tmpFileUrl error:nil];
        _tmpFileUrl = nil;
    }
}

@end
