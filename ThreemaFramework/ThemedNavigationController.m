//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2020 Threema GmbH
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

#import "ThemedNavigationController.h"
#import "ThemedTableViewController.h"
#import "VoIPHelper.h"

@implementation ThemedNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callInBackground:) name:kNotificationCallInBackground object:nil];
    
    [Colors updateNavigationBar:self.navigationBar];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)colorThemeChanged:(NSNotification*)notification {
    for (UIViewController *vc in self.viewControllers) {
        if ([vc respondsToSelector:@selector(refresh)]) {
            [vc performSelector:@selector(refresh)];
        }
    }
    
    [Colors updateNavigationBar:self.navigationBar];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)callInBackground:(NSNotification*)notification {
    [Colors updateNavigationBar:self.navigationBar];
}

@end
