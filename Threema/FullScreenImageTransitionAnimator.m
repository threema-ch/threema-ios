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

#import "FullScreenImageTransitionAnimator.h"
#import "FullscreenImageViewController.h"
#import "GroupDetailsViewController.h"
#import "ContactDetailsViewController.h"
#import "MyIdentityViewController.h"
#import "ContactsViewController.h"
#import "Threema-Swift.h"
@interface FullScreenImageTransitionAnimator ()

@property NSTimeInterval duration;

@end

@implementation FullScreenImageTransitionAnimator

- (instancetype)init
{
    self = [super init];
    if (self) {
        _duration = 0.4f;
    }
    return self;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return _duration;
}


- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    if ([transitionContext isAnimated] == NO) {
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        return;
    }
    
    // Setup for animation transition
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toVC   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    if ([fromVC isKindOfClass:[FullscreenImageViewController class]] && [toVC isKindOfClass:[GroupDetailsViewController class]]) {
        GroupDetailsViewController *gVC = (GroupDetailsViewController *)toVC;
        [self animateImage:(FullscreenImageViewController *)fromVC toImageVC:gVC view:gVC.imageView context:transitionContext];
    } else if ([fromVC isKindOfClass:[GroupDetailsViewController class]] && [toVC isKindOfClass:[FullscreenImageViewController class]]) {
        GroupDetailsViewController *gVC = (GroupDetailsViewController *)fromVC;
        [self animateFromVC:gVC toImageVC:(FullscreenImageViewController *)toVC  view:gVC.imageView context:transitionContext];
    } else if ([fromVC isKindOfClass:[FullscreenImageViewController class]] && [toVC isKindOfClass:[ContactDetailsViewController class]]) {
        ContactDetailsViewController *cVC = (ContactDetailsViewController *)toVC;
        [self animateImage:(FullscreenImageViewController *)fromVC toImageVC:cVC view:cVC.imageView context:transitionContext];
    } else if ([fromVC isKindOfClass:[ContactDetailsViewController class]] && [toVC isKindOfClass:[FullscreenImageViewController class]]) {
        ContactDetailsViewController *cVC = (ContactDetailsViewController *)fromVC;
        [self animateFromVC:cVC toImageVC:(FullscreenImageViewController *)toVC  view:cVC.imageView context:transitionContext];
    } else if ([fromVC isKindOfClass:[FullscreenImageViewController class]] && [toVC isKindOfClass:[MeContactDetailsViewController class]]) {
        MeContactDetailsViewController *gVC = (MeContactDetailsViewController *)toVC;
        [self animateImage:(FullscreenImageViewController *)fromVC toImageVC:gVC view:gVC.imageView context:transitionContext];
    } else if ([fromVC isKindOfClass:[MeContactDetailsViewController class]] && [toVC isKindOfClass:[FullscreenImageViewController class]]) {
        MeContactDetailsViewController *gVC = (MeContactDetailsViewController *)fromVC;
        [self animateFromVC:gVC toImageVC:(FullscreenImageViewController *)toVC  view:gVC.imageView context:transitionContext];
    }
    else if ([fromVC isKindOfClass:[FullscreenImageViewController class]] && [toVC isKindOfClass:[ContactsViewController class]]) {
        ContactsViewController *cVC = (ContactsViewController *)toVC;
        [self animateImage:(FullscreenImageViewController *)fromVC toImageVC:cVC view:cVC.segmentedControl context:transitionContext];
    }
    else {
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }
}

- (void)animateImage:(FullscreenImageViewController *)imageVC toImageVC:(UIViewController *)presentingVC view:(UIView *)view context:(id<UIViewControllerContextTransitioning>)transitionContext {
    
    UIView *containerView = [transitionContext containerView];
    
    UIImageView *animatedView = [imageVC createImageView];
    
    CGRect finalRect = [transitionContext finalFrameForViewController:presentingVC];
    CGRect destRect = [presentingVC.view convertRect:view.frame fromView:view.superview];
    destRect = CGRectOffset(destRect, 0.0, finalRect.origin.y);
    
    CGRect srcRect = [containerView convertRect:animatedView.frame fromView:imageVC.view];
    
    [containerView addSubview:presentingVC.view];
    
    presentingVC.view.alpha = 0.0;
    animatedView.alpha = 1.0;
    animatedView.frame = srcRect;
    [containerView addSubview:animatedView];
    
    [UIView animateWithDuration:_duration delay:0.0 usingSpringWithDamping:0.75 initialSpringVelocity:0.0 options:0 animations:^{
        animatedView.frame = destRect;
        animatedView.alpha = 0.0;
        presentingVC.view.alpha = 1.0;
    } completion:^(BOOL finished) {
        [animatedView removeFromSuperview];
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

- (void)animateFromVC:(UIViewController *)presentingVC toImageVC:(FullscreenImageViewController *)imageVC view:(UIView *)view context:(id<UIViewControllerContextTransitioning>)transitionContext {
    
    UIView *containerView    = [transitionContext containerView];
    UIImageView *animatedView = [imageVC createImageView];
    [containerView addSubview:presentingVC.view];
    
    CGRect finalRect = [transitionContext finalFrameForViewController:imageVC];
    animatedView.frame = CGRectOffset(animatedView.frame, 0.0, finalRect.origin.y);

    CGRect srcRect = [containerView convertRect:view.frame fromView:view.superview];
    CGRect destRect = animatedView.frame;
    
    UIView *bgView = [[UIView alloc] initWithFrame:containerView.bounds];
    bgView.backgroundColor = imageVC.view.backgroundColor;
    bgView.alpha = 0.0;
    [containerView addSubview:bgView];
    
    animatedView.alpha = 0.0;
    animatedView.frame = srcRect;
    [containerView addSubview:animatedView];
    
    [UIView animateWithDuration:_duration delay:0.0 usingSpringWithDamping:0.75 initialSpringVelocity:0.0 options:0 animations:^{
        animatedView.frame = destRect;
        animatedView.alpha = 1.0;
        bgView.alpha = 1.0;
        presentingVC.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [containerView addSubview:imageVC.view];
        [animatedView removeFromSuperview];
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

@end
