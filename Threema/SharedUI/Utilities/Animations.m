//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2024 Threema GmbH
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

#import "Animations.h"
#import "RectUtil.h"

@implementation Animations

+ (void) bounceToRect:(CGRect)toFrame view: (UIView *) view endAction: (void (^)(void)) action
{
    CGRect finalRect = view.frame;
    
    [view.superview bringSubviewToFront: view];
    
    UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseInOut;
    [UIView animateWithDuration:0.5 delay:0.0 options: options animations:^{
        view.frame = toFrame;
        view.hidden = NO;
    } completion:^(BOOL finished){
        [UIView animateWithDuration:0.9 delay:0.1 options: options animations:^{
            
            view.frame = finalRect;
            
        } completion:^(BOOL finished){
            if (action) {
                action();
            }
        }];
    }];
}

+ (void) slideFromLeftBounce: (UIView *) view endAction: (void (^)(void)) action
{
    CGRect finalRect = view.frame;
    CGRect startRect = [RectUtil setXPositionOf:view.frame x: - (view.frame.origin.x + view.frame.size.width)];
    CGRect intermediateRect = [RectUtil setXPositionOf:view.frame x:view.frame.origin.x + 10];
    
    view.frame = startRect;
    view.hidden = NO;
    
    [view.superview bringSubviewToFront: view];
    
    UIViewAnimationOptions options = 0;
    [UIView animateWithDuration:0.5 delay:0.0 options: options animations:^{
        view.frame = intermediateRect;
        view.hidden = NO;
    } completion:^(BOOL finished){
        [UIView animateWithDuration:0.25 delay:0.0 options: options animations:^{
            
            view.frame = finalRect;
            
        } completion:^(BOOL finished){
            if (action) {
                action();
            }
        }];
    }];
}

+ (void) scaleBounceView: (UIView *) view max: (CGFloat) max min: (CGFloat) min endAction: (void (^)(void)) action
{
    CGAffineTransform scaleBig = CGAffineTransformScale(CGAffineTransformIdentity, max, max);
    CGAffineTransform scaleSmall = CGAffineTransformScale(CGAffineTransformIdentity, min, min);
    
    [view.superview bringSubviewToFront: view];
    
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.2 delay:0.0 options: options animations:^{
        
        view.transform = scaleBig;
        
    } completion:^(BOOL finished){
        [UIView animateWithDuration:0.1 delay:0.0 options: options animations:^{
            
            view.transform = scaleSmall;
            
        } completion:^(BOOL finished){
            view.transform = CGAffineTransformIdentity;
            
            if (action) {
                action();
            }
        }];
    }];
}

@end
