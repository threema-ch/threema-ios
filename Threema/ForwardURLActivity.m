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

#import "ForwardURLActivity.h"
#import "ContactGroupPickerViewController.h"
#import "MessageSender.h"
#import "ModalNavigationController.h"
#import "FeatureMaskChecker.h"
#import "UTIConverter.h"
#import "FileMessageSender.h"

@interface ForwardURLActivity () <ContactGroupPickerDelegate, ModalNavigationControllerDelegate>

@property NSURL *url;
@property NSNumber *renderType;

@end

@implementation ForwardURLActivity

+ (UIActivityCategory)activityCategory {
    return UIActivityCategoryAction;
}

- (NSString *)activityType {
    return APP_ID ".forwardMsg";
}

- (NSString *)activityTitle {
    return NSLocalizedString(@"forward", nil);
}

- (UIImage *)activityImage {
    return [UIImage imageNamed:@"ShareForward"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    if (activityItems.count != 1) {
        return NO;
    }
    
    id item = activityItems[0];
    if ([item isKindOfClass:[NSURL class]]) {
        return YES;
    }
    if ([item isKindOfClass:[NSDictionary class]]) {
        NSDictionary *itemDict = (NSDictionary *)item;
        if ([itemDict[@"url"] isKindOfClass:[NSURL class]]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    if ([activityItems[0] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *itemDict = (NSDictionary *)activityItems[0];
        if ([itemDict[@"url"] isKindOfClass:[NSURL class]]) {
            _url = itemDict[@"url"];
            _renderType = itemDict[@"renderType"];
        }
    } else {
        _url = activityItems[0];
        _renderType = @0;
    }
}

- (UIViewController *)activityViewController {
    ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
    ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)navigationController.topViewController;
    picker.enableMulitSelection = true;
    picker.enableTextInput = true;
    picker.submitOnSelect = false;
    picker.renderType = _renderType;
    return navigationController;
}

#pragma mark - ContactPickerDelegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    FeatureMaskChecker *featureMaskChecker = [[FeatureMaskChecker alloc] init];
    
    [featureMaskChecker checkFileTransferFor:conversations presentAlarmOn:contactPicker onSuccess:^{
        for (Conversation *conversation in conversations) {
            [URLSender sendUrl:_url asFile:sendAsFile caption:contactPicker.additionalTextToSend conversation:conversation];
        }
        
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } onFailure:^{
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)contactPickerDidCancel:(ContactGroupPickerViewController*)contactPicker {
    [contactPicker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ModalNavigationControllerDelegate

- (void)willDismissModalNavigationController {
    
}

@end
