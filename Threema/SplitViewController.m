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

#import "SplitViewController.h"
#import "MainTabBarController.h"

@interface SplitViewControllerDelegate : NSObject <UISplitViewControllerDelegate>

@end

@interface SplitViewController ()

@property MainTabBarController *tabViewController;
@property SplitViewControllerDelegate *splitViewContorllerDelegate;

@end

@implementation SplitViewController

- (void)setup {
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    _tabViewController = [mainStoryboard instantiateInitialViewController];
    
    self.viewControllers = @[
                             [[UIViewController alloc] init],
                             _tabViewController
                             ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    switch ([Colors getTheme]) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            return UIStatusBarStyleLightContent;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            return UIStatusBarStyleDefault;
            
        default:
            break;
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
