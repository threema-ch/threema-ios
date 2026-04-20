#import "ThemedNavigationController.h"
#import "ThemedTableViewController.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation ThemedNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)colorThemeChanged:(NSNotification*)notification {
    for (UIViewController *vc in self.viewControllers) {
        if ([vc respondsToSelector:@selector(refresh)]) {
            [vc performSelector:@selector(refresh)];
        }
        if (vc.presentedViewController != nil) {
            if ([vc.presentedViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *presentedNav = (UINavigationController *)vc.presentedViewController;
                
                for (UIViewController *vc in presentedNav.childViewControllers) {
                    if ([vc respondsToSelector:@selector(refresh)]) {
                        [vc performSelector:@selector(refresh)];
                    }
                }
            }
        }
    }
    
    [self setNeedsStatusBarAppearanceUpdate];
}

@end
