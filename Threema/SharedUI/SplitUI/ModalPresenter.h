#import <Foundation/Foundation.h>

@interface ModalPresenter : NSObject

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller;

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller fromRect:(CGRect)fromRect inView:(UIView *)inView;

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller fromRect:(CGRect)fromRect inView:(UIView *)inView completion:(void(^)(void))completion;

+ (void) present:(UIViewController *)controllerToPresent on:(UIViewController *)controller fromBarButton:(UIBarButtonItem *)barButtonItem;

+ (void) dismissPresentedControllerOn:(UIViewController *)presentingViewController animated:(BOOL)animated;

+ (void) dismissPresentedControllerOn:(UIViewController *)presentingViewController animated:(BOOL)animated completion:(void (^)(void))completion;

@end
