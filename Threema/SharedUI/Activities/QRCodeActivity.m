//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "QRCodeActivity.h"
#import "QRCodeViewController.h"
#import "PortraitNavigationController.h"
#import "Threema-Swift.h"
#import "BundleUtil.h"

@implementation QRCodeActivity {
    NSString *qrData;
}

+ (UIActivityCategory)activityCategory {
    return UIActivityCategoryAction;
}

- (NSString *)activityType {
    return [NSString stringWithFormat:@"%@.genqr", [[BundleUtil mainBundle] bundleIdentifier]];
}

- (NSString *)activityTitle {
    return [BundleUtil localizedStringForKey:@"qr_code"];
}

- (UIImage *)activityImage {
    return [UIImage imageNamed:@"QRScan"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    return (activityItems.count == 1 && [activityItems[0] isKindOfClass:[NSString class]]);
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    qrData = activityItems[0];
}

- (UIViewController *)activityViewController {
    QRCodeViewController *viewController = [[QRCodeViewController alloc] init];
    viewController.qrData = qrData;
    viewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed)];
    UINavigationController *navController = [[PortraitNavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
    [navController pushViewController:viewController animated:NO];
    return navController;
}

- (void)donePressed {
    [self activityDidFinish:YES];
}

@end
