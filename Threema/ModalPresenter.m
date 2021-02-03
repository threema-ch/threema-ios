//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "ModalPresenter.h"

@implementation ModalPresenter

static UIViewController *pickerPopover;

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller {
    [self present:controllerToPresent on:controller fromRect:controller.view.bounds inView:controller.view];
}

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller fromRect:(CGRect)fromRect inView:(UIView *)inView {
    [ModalPresenter present:controllerToPresent on:controller fromRect:fromRect inView:inView completion:nil];
}

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller fromRect:(CGRect)fromRect inView:(UIView *)inView completion:(void(^)(void))completion {
    if ([self shouldPresentInPopover:controllerToPresent]) {
        pickerPopover = controllerToPresent;
        pickerPopover.modalPresentationStyle = UIModalPresentationPopover;
        pickerPopover.popoverPresentationController.sourceView = inView;
        pickerPopover.popoverPresentationController.sourceRect = fromRect;
        
        [controller presentViewController:controllerToPresent animated:YES completion:completion];
    } else {
        [controller presentViewController:controllerToPresent animated:YES completion:completion];
    }
}

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller fromBarButton:(UIBarButtonItem *)barButtonItem {
    if ([self shouldPresentInPopover:controllerToPresent]) {
        pickerPopover = controllerToPresent;
        pickerPopover.modalPresentationStyle = UIModalPresentationPopover;
        pickerPopover.popoverPresentationController.barButtonItem = barButtonItem;
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller presentViewController:controllerToPresent animated:YES completion:nil];
        });
    } else {
        [controller presentViewController:controllerToPresent animated:YES completion:nil];
    }
}

+ (BOOL) shouldPresentInPopover:(UIViewController *)controller {
    if (SYSTEM_IS_IPAD) {
        if ([controller isKindOfClass:[UIImagePickerController class]]) {
            UIImagePickerController *picker = (UIImagePickerController *)controller;
            return (picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary);
        } else {
            return YES;
        }
    }
    
    return NO;
}

+ (void) dismissPresentedControllerOn:(UIViewController *)presentingViewController animated:(BOOL)animated {
    [self dismissPresentedControllerOn:presentingViewController animated:YES completion:nil];
}

+ (void) dismissPresentedControllerOn:(UIViewController *)presentingViewController animated:(BOOL)animated completion:(void (^)(void))completion {
        
    if (pickerPopover) {
        [pickerPopover dismissViewControllerAnimated:YES completion:completion];
    } else {
        [presentingViewController dismissViewControllerAnimated:YES completion:completion];
    }
    pickerPopover = nil;
}

@end
