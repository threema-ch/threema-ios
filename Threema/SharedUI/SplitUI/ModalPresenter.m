#import "ModalPresenter.h"
#import <UIKit/UIKit.h>
#import <ThreemaFramework/Constants.h>

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
        pickerPopover.modalPresentationStyle = UIModalPresentationAutomatic;
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
        pickerPopover.modalPresentationStyle = UIModalPresentationAutomatic;
        pickerPopover.popoverPresentationController.barButtonItem = barButtonItem;
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller presentViewController:controllerToPresent animated:YES completion:nil];
        });
    } else {
        [controller presentViewController:controllerToPresent animated:YES completion:nil];
    }
}

+ (BOOL) shouldPresentInPopover:(UIViewController *)controller {
    if (controller.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
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
