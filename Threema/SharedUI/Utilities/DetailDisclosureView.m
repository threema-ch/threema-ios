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

#import "DetailDisclosureView.h"
#import "RectUtil.h"
#import "Animations.h"

#define GESTURE_SWIPE_MIN_SPEED 150.0
#define GESTURE_SWIPE_MIN_POINTS 50.0
#define GESTURE_SWIPE_MAX_DURATION 0.3

#define BOUNCE_OFFSET 80.0

@interface DetailDisclosureView ()

@property CGFloat currentXPos;
@property BOOL showDetails;

@property UIView *dragIndicator;

@end

@implementation DetailDisclosureView

@synthesize ddDetailView = _ddDetailView, ddMainView = _ddMainView;

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self addGestureRecognizer:pan];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self addGestureRecognizer:tap];
    
    self.bounceOffset = BOUNCE_OFFSET;
    self.clipsToBounds = YES;
}

- (void)moveViewsWithVelocity:(CGPoint) velocity toXOffset:(CGFloat) xOffset
{
    CGFloat points2move = fabs(self.ddMainView.frame.origin.x - xOffset);
    CGFloat duration = points2move / fabs(velocity.x);
    duration = MIN(duration, GESTURE_SWIPE_MAX_DURATION);
    
    UIViewAnimationOptions options = UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        [self positionViewsAtX:xOffset];
    } completion:^(BOOL finished) {
    }];
}

- (void)positionViewsAtX:(CGFloat)x {
    _currentXPos = x;
    
    self.ddMainView.frame = [RectUtil setXPositionOf:self.ddMainView.frame x: x];
    self.ddDetailView.frame = [RectUtil setXPositionOf:self.ddDetailView.frame x: x + CGRectGetWidth(self.ddMainView.frame)];
}

+ (CGFloat)limit:(CGFloat)value toMin:(CGFloat)min max:(CGFloat)max {
    CGFloat result = fminf(value, max);
    result = fmaxf(result, min);
    
    return result;
}

- (void)moveViewsByX:(CGFloat)diffX
{
    CGFloat newX = _currentXPos + diffX;
    
    if (newX <= - CGRectGetWidth(_ddDetailView.frame) || newX >= 0.0) {
        return;
    }
    
    [self positionViewsAtX:newX];
}

#pragma mark - Animations

- (void)bounceDetailView {
    [self bringSubviewToFront:_ddDetailView];
    
    CGRect startRect = [RectUtil setXPositionOf:_ddDetailView.frame x: (self.frame.size.width - _bounceOffset)];
    
    [Animations bounceToRect:startRect view:_ddDetailView endAction:nil];
}

- (void)toggleDetailView {
    CGFloat xOffset;
    if (_showDetails) {
        xOffset = 0.0;
    } else {
        xOffset = - CGRectGetWidth(_ddDetailView.frame);
    }

    _showDetails = !_showDetails;

    CGPoint velocity = CGPointMake(GESTURE_SWIPE_MIN_SPEED, 0.0);
    [self moveViewsWithVelocity:velocity toXOffset:xOffset];
}

#pragma mark - UIPanGestureRecognizer

- (void)tap:(UIPanGestureRecognizer *)recognizer {
    [self toggleDetailView];
}

- (void)pan:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint transformed = [recognizer translationInView:self];
        
        [self moveViewsByX:transformed.x];

        [recognizer setTranslation:CGPointZero inView:self];
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGFloat xOffset;
        
        if ([self movedLeftAcrossTrigger] && [self checkSpeedTrigger:recognizer]) {
            xOffset = 0.0 - CGRectGetWidth(_ddDetailView.frame);
            _showDetails = YES;
        } else if ([self movedRightAcrossTrigger] && [self checkSpeedTrigger:recognizer]) {
            xOffset = 0.0;
            _showDetails = NO;
        } else {
            if (_showDetails) {
                xOffset = - CGRectGetWidth(_ddDetailView.frame);
            } else {
                xOffset = 0.0;
            }
        }
        
        CGPoint velocity = [recognizer velocityInView:self];
        [self moveViewsWithVelocity:velocity toXOffset:xOffset];
    }
}

- (BOOL)checkSpeedTrigger:(UIPanGestureRecognizer *)recognizer
{
    CGPoint velocity = [recognizer velocityInView:self];
    return (fabs(velocity.x) > GESTURE_SWIPE_MIN_SPEED);
}

- (BOOL)movedRightAcrossTrigger
{
    return _showDetails && _ddMainView.frame.origin.x + CGRectGetWidth(_ddDetailView.frame) > GESTURE_SWIPE_MIN_POINTS;
}

- (BOOL)movedLeftAcrossTrigger
{
    return _showDetails == NO && _ddMainView.frame.origin.x < -GESTURE_SWIPE_MIN_POINTS;
}

@end
