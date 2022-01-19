//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

#import "ThemedViewController.h"
#import "VoIPHelper.h"

@interface ThemedViewController ()

@end

@implementation ThemedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setBackgroundColor:[Colors background]];
    [Colors setTextColor:[Colors fontNormal] inView:self.view];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callInBackgroundTimeChanged:) name:kNotificationCallInBackgroundTimeChanged object:nil];
    self.navigationItem.prompt = [[VoIPHelper shared] currentPromtString:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationCallInBackgroundTimeChanged object:nil];
}

- (void)callInBackgroundTimeChanged:(NSNotification*)notification {
    NSNumber *time = notification.object;
    self.navigationItem.prompt = [[VoIPHelper shared] currentPromtString:time];
    
    if (self.navigationItem.prompt == nil) {
        if ([self respondsToSelector:@selector(updateLayoutAfterCall)]) {
            double delayInSeconds = 0.3;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self performSelector:@selector(updateLayoutAfterCall)];
            });
        }
    }
}

- (void)refresh {
    [self.view setBackgroundColor:[Colors background]];
    
    [Colors setTextColor:[Colors fontNormal] inView:self.view];
}

- (void)updateLayoutAfterCall {
    // do nothing
}

@end

