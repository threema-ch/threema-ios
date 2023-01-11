//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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
#import "ThreemaUtilityObjC.h"
#import "Threema-Swift.h"

#import <PassKit/PassKit.h>
#import <QuickLook/QuickLook.h>
#import "MDMSetup.h"

@interface FileMessagePreview () <ModalNavigationControllerDelegate, QLPreviewControllerDataSource, UIDocumentInteractionControllerDelegate>

@property FileMessageEntity *fileMessageEntity;
@property UIViewController *previewBaseController;
@property NSURL *tmpFileUrl;

@end

@implementation FileMessagePreview

+ (instancetype)fileMessagePreviewFor:(FileMessageEntity *)fileMessageEntity {
    FileMessagePreview *preview = [[FileMessagePreview alloc] init];
    preview.fileMessageEntity = fileMessageEntity;
    
    return preview;
}

+ (BOOL)shouldExportToURL:(FileMessageEntity *)fileMessageEntity {
    if ([fileMessageEntity.mimeType isEqualToString:@"text/vcard"]) {
        return NO;
    }
    
    return YES;
}

+ (UIImage *)thumbnailForFileMessageEntity:(FileMessageEntity *)fileMessageEntity {
    UIImage *thumbnailImage;
    if (fileMessageEntity.thumbnail) {
        thumbnailImage = fileMessageEntity.thumbnail.uiImage;
    }
    
    if (thumbnailImage == nil) {
        // not existing or invalid data
        thumbnailImage = [UTIConverter getDefaultThumbnailForMimeType:fileMessageEntity.mimeType];
        
        // colorize
        thumbnailImage = [thumbnailImage imageWithTint:Colors.text];
    }
    return thumbnailImage;
}

- (void)addShareButtonTo:(UIViewController *)viewController {
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareButtonTapped:)];
    viewController.navigationItem.rightBarButtonItem = shareButton;
}

- (ModalNavigationController *)setupNavigationControllerWithRootViewController:(UIViewController *)rootViewController {
    ModalNavigationController *navigationController = [[ModalNavigationController alloc] initWithRootViewController:rootViewController];
    navigationController.showLeftDoneButton = YES;
    navigationController.dismissOnTapOutside = YES;
    navigationController.showFullScreenOnIPad = YES;
    navigationController.navigationBar.scrollEdgeAppearance = [Colors defaultNavigationBarAppearance];
    return navigationController;
}

- (void)showOn:(UIViewController *)targetViewController {
    if ([UTIConverter isContactMimeType:_fileMessageEntity.mimeType]) {
        [self checkContactAccessFor:targetViewController];
    }
    else if ([UTIConverter isAudioMimeType:_fileMessageEntity.mimeType]) {
        MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
        if ([mdmSetup disableShareMedia] == false) {
            [self showUsingDocumentInteractionControllerOn:targetViewController];
        } else {
            [self showUsingQuickLookPreviewOn:targetViewController];
        }
    }
    else if ([UTIConverter isPassMimeType:_fileMessageEntity.mimeType]) {
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
                    NSString *message = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"no_contacts_permission_message"], [ThreemaAppObjc currentName]];
                    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"no_contacts_permission_title"] message:message actionOk:nil];
                });
            }
        }];
    } else {
        [self showContactOn:targetViewController];
    }
}

- (void)showContactOn:(UIViewController *)targetViewController {
    UIViewController *personViewController = [ContactUtil getContactViewControllerForVCardData:_fileMessageEntity.data.data];
    _previewBaseController = [self setupNavigationControllerWithRootViewController:personViewController];

    [targetViewController presentViewController:_previewBaseController animated:YES completion:nil];
}

- (void)showUsingDocumentInteractionControllerOn:(UIViewController *)targetViewController {
    NSString *filename = [FileUtility getTemporarySendableFileNameWithBase:@"file"];
    _tmpFileUrl = [_fileMessageEntity tmpURL:filename];
    [_fileMessageEntity exportDataToURL:_tmpFileUrl];
        
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
    _tmpFileUrl = [_fileMessageEntity tmpURL:filename];
    [_fileMessageEntity exportDataToURL:_tmpFileUrl];
    
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
    PKPass *pass = [[PKPass alloc] initWithData:_fileMessageEntity.data.data error:&error];
    if (pass != nil) {
        PKAddPassesViewController *addPassVc = [[PKAddPassesViewController alloc] initWithPass:pass];
        [targetViewController presentViewController:addPassVc animated:YES completion:nil];
    } else {
        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
    }
}

- (void)shareButtonTapped:(UIBarButtonItem *)sender {
    UIActivityViewController *activityViewController = [ActivityUtil activityViewControllerForMessage:_fileMessageEntity withView:_previewBaseController.view andBarButtonItem:sender];
    NSUserDefaults *defaults = [AppGroup userDefaults];
    [defaults setDouble:[ThreemaUtilityObjC systemUptime] forKey:@"UIActivityViewControllerOpenTime"];
    [defaults synchronize];
    [activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults removeObjectForKey:@"UIActivityViewControllerOpenTime"];
    }];
    [ModalPresenter present:activityViewController on:_previewBaseController fromBarButton:sender];
}

- (void)addThumbnailViewTo:(UIView *)view {
    FileMessagePreviewUnsupportedTypeView *fileView = [FileMessagePreviewUnsupportedTypeView fileMessagePreviewUnsupportedTypeView];
    fileView.fileMessageEntity = _fileMessageEntity;
    
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
