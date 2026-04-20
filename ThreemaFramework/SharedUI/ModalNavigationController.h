#import <UIKit/UIKit.h>
#import "ThemedNavigationController.h"

@protocol ModalNavigationControllerDelegate <NSObject>

- (void)didDismissModalNavigationController;

@end

@interface ModalNavigationController : ThemedNavigationController

@property BOOL showDoneButton;

/// Prefer `showDoneButton` over this. Use this if the system already draws something on the right side
@property BOOL showLeftDoneButton;

@property (nonatomic) BOOL dismissOnTapOutside;

@property BOOL showFullScreenOnIPad;

@property (weak) id<ModalNavigationControllerDelegate> modalDelegate;

@end
