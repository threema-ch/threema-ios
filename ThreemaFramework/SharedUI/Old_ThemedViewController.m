//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

#import "Old_ThemedViewController.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@interface Old_ThemedViewController ()

@end

@implementation Old_ThemedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = Colors.backgroundViewController;
    [Colors setTextColor:Colors.text in:self.view];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(navigationItemPromptShouldChange:) name:kNotificationNavigationItemPromptShouldChange object:nil];
    self.navigationItem.prompt = [NavigationBarPromptHandler getCurrentPromptWithDuration:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationNavigationItemPromptShouldChange object:nil];
}

- (void)navigationItemPromptShouldChange:(NSNotification*)notification {
    NSNumber *time = notification.object;
    self.navigationItem.prompt = [NavigationBarPromptHandler getCurrentPromptWithDuration:time];
    
    self.view.backgroundColor = [Colors backgroundViewController];
    [Colors setTextColor:Colors.text in:self.view];
    
    [self.navigationController.view setNeedsLayout];
    [self.navigationController.view layoutIfNeeded];
    [self.navigationController.view setNeedsDisplay];
}

- (void)refresh {
    [Colors setTextColor:Colors.text in:self.view];
}

@end

