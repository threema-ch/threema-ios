//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "AnimatedNavigationController.h"
#import "FullscreenImageViewController.h"
#import "FullScreenImageTransitionAnimator.h"

@interface AnimatedNavigationController () <UINavigationControllerDelegate>

@end

@implementation AnimatedNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.delegate = self;
    
    [self.view setBackgroundColor:[Colors background]];
}

#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC {
    
    if (UINavigationControllerOperationPush && [toVC isKindOfClass:[FullscreenImageViewController class]]) {
        FullScreenImageTransitionAnimator *animator = [FullScreenImageTransitionAnimator new];
        return animator;
    }

    if (UINavigationControllerOperationPop && [fromVC isKindOfClass:[FullscreenImageViewController class]]) {
        FullScreenImageTransitionAnimator *animator = [FullScreenImageTransitionAnimator new];
        return animator;
    }
    
    return nil;
}

@end
