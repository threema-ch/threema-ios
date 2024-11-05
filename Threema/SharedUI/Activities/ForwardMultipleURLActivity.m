//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

#import "ForwardMultipleURLActivity.h"
#import "ContactGroupPickerViewController.h"
#import "ModalNavigationController.h"
#import "BundleUtil.h"

@interface ForwardMultipleURLActivity () <ContactGroupPickerDelegate, ModalNavigationControllerDelegate>

@property NSMutableArray *objects;

@end

@implementation ForwardMultipleURLActivity

+ (UIActivityCategory)activityCategory {
    return UIActivityCategoryAction;
}

- (NSString *)activityType {
    return [NSString stringWithFormat:@"%@.forwardMsg", [[BundleUtil mainBundle] bundleIdentifier]];
}

- (NSString *)activityTitle {
    return [BundleUtil localizedStringForKey:@"forward"];
}

- (UIImage *)activityImage {
    return [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    if (activityItems.count > 20) {
        return NO;
    }
    
    for (id item in activityItems) {
        if (![item isKindOfClass:[NSURL class]]) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSDictionary *itemDict = (NSDictionary *)item;
                if (![itemDict[@"url"] isKindOfClass:[NSURL class]]) {
                    return false;
                }
            } else {
                return false;
            }
        }
    }
    
    return true;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    if (_objects == nil) {
        _objects = [NSMutableArray new];
    }
    [_objects removeAllObjects];
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *itemDict = (NSDictionary *)item;
            if ([itemDict[@"url"] isKindOfClass:[NSURL class]]) {
                NSMutableDictionary *object = [NSMutableDictionary new];
                [object setObject:itemDict[@"url"] forKey:@"url"];
                [object setObject:itemDict[@"renderType"] forKey:@"renderType"];
                [_objects addObject:object];
            }
        } else {
            NSMutableDictionary *object = [NSMutableDictionary new];
            [object setObject:item forKey:@"url"];
            [object setObject:@0 forKey:@"renderType"];
            [_objects addObject:object];
        }
    }
}

- (UIViewController *)activityViewController {
    ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
    ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)navigationController.topViewController;
    picker.enableMultiSelection = true;
    picker.enableTextInput = true;
    picker.submitOnSelect = false;
    picker.renderType = @0;
    return navigationController;
}

#pragma mark - ContactPickerDelegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    for (NSDictionary *object in _objects) {
        NSURL *url = object[@"url"];

        for (ConversationEntity *conversation in conversations) {
            [URLSender sendURL:url asFile:sendAsFile caption:contactPicker.additionalTextToSend conversation:conversation];
        }
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)contactPickerDidCancel:(ContactGroupPickerViewController*)contactPicker {
    [contactPicker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ModalNavigationControllerDelegate

- (void)didDismissModalNavigationController {
    
}

@end
