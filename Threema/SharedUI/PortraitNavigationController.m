#import "PortraitNavigationController.h"

@interface PortraitNavigationController ()

@end

@implementation PortraitNavigationController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}
    
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

/// Resizable scenes on iOS 26+ ignore `supportedInterfaceOrientations`, lock the orientation instead
- (BOOL)prefersInterfaceOrientationLocked {
    return YES;
}
@end
