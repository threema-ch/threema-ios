//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "PageView.h"
#import "RectUtil.h"

@interface PageView ()

@property PagingDirection direction;
@property UIPanGestureRecognizer *panGesture;

@end

@implementation PageView

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {        
        // clip if not on entire screen
        if (self.superview != nil && self.superview.frame.size.width > self.frame.size.width) {
            self.clipsToBounds = YES;
        }        
        
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        [self addGestureRecognizer:_panGesture];
        
        _pageGap = DEFAULT_PAGE_GAP;
        _parallaxFactor = DEFAULT_PARALLAX_FACTOR;
    }
    
    return self;
}

- (void)setBgView:(UIView *)bgView {
    _bgView = bgView;
    
    [self addSubview:_bgView];
    [self sendSubviewToBack:_bgView];
}

- (void) setHidden: (BOOL)hidden
{
    [super setHidden: hidden];
    
    _centerView.hidden = hidden;
    _rightView.hidden = hidden;
    _leftView.hidden = hidden;
}

- (void) setDatasource:(id<PageViewDataSource>)datasource
{
    _datasource = datasource;
    
    [self reset];
}

- (void) resetPageFrames
{
    self.leftView.frame = self.bounds;
    self.centerView.frame = self.bounds;
    self.rightView.frame = self.bounds;
    
    BOOL animationsEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    [self positionViews];
    [UIView setAnimationsEnabled:animationsEnabled];
}

- (void) reset
{
    [self preparePagedViews];
    [self positionViews];
}

- (void) pageLeft
{
    BOOL changePage = [self preparePageLeft];
    [self positionViewsWithDuration: MAX_ANIMATION_DURATION changePage:changePage];
}

- (void) pageRight
{
    BOOL changePage = [self preparePageRight];
    [self positionViewsWithDuration: MAX_ANIMATION_DURATION changePage:changePage];
}

- (void)enablePanGesture:(BOOL)enablePan {
    _panGesture.enabled = enablePan;
}

#pragma mark - UIPanGestureRecognizer

- (void) pan: (UIPanGestureRecognizer *) recognizer
{
        if (recognizer.state == UIGestureRecognizerStateBegan) {
        } else if (recognizer.state == UIGestureRecognizerStateChanged) {
            CGPoint transformed = [recognizer translationInView:self];

            [self moveAllViewsByX:transformed.x];
            
            [recognizer setTranslation:CGPointZero inView:self];
        } else if (recognizer.state == UIGestureRecognizerStateEnded) {
            BOOL changePage = NO;
            if ([self movedLeftAcrossTrigger] && [self checkSpeedTrigger:recognizer]) {
                changePage = [self preparePageLeft];
            } else if ([self movedRightAcrossTrigger] && [self checkSpeedTrigger:recognizer]) {
                changePage = [self preparePageRight];
            }
            
            CGPoint velocity = [recognizer velocityInView:self];
            [self positionViewsWithVelocity: velocity changePage:changePage];
        }
}

- (BOOL) checkSpeedTrigger: (UIPanGestureRecognizer *) recognizer
{
    CGPoint velocity = [recognizer velocityInView:self];
    return (fabs(velocity.x) > MIN_PAGE_PAN_SPEED);
}

- (BOOL) movedRightAcrossTrigger
{
    return (self.centerView.frame.origin.x ) > MIN_PAGE_PAN_POINTS;
}

- (BOOL) movedLeftAcrossTrigger
{
    return (self.centerView.frame.origin.x ) < -MIN_PAGE_PAN_POINTS;
}

- (void) moveAllViewsByX: (CGFloat) x
{
    [self moveView:self.leftView X:x Y:0];
    [self moveView:self.centerView X:x Y:0];
    [self moveView:self.rightView X:x Y:0];
    
    [self moveView:_bgView X:x*_parallaxFactor Y:0.0];
}

- (void) moveView: (UIView *) view X: (CGFloat) x Y: (CGFloat) y
{
    CGRect moved = view.frame;
    moved.origin.x += x;
    
    view.frame = moved;
}

- (void) placeView: (UIView *) view X: (CGFloat) x Y: (CGFloat) y
{
    CGRect newPos = view.frame;
    newPos.origin.x = x;
    newPos.origin.y = y;
    
    view.frame = newPos;
}

- (BOOL) preparePageRight
{
    BOOL canPage = [self.datasource moveToPrevious];
    if (canPage == NO) {
        return NO;
    }
 
    [self.rightView removeFromSuperview];

    self.rightView = self.centerView;
    self.centerView = self.leftView;
    self.leftView = [self.datasource previousView: self.bounds];
    
    [self addSubview:self.leftView];

    [self placeView:self.leftView X:-self.frame.size.width Y:self.leftView.frame.origin.y];
    
    _direction = RIGHT;
    if ([_delegate respondsToSelector: @selector(willPageFrom:toView:)]) {
        [_delegate willPageFrom:self.rightView toView:self.centerView];
    }
    
    return YES;
}

- (BOOL) preparePageLeft
{
    BOOL canPage = [self.datasource moveToNext];
    if (canPage == NO) {
        return NO;
    }
 
    [self.leftView removeFromSuperview];

    self.leftView = self.centerView;
    self.centerView = self.rightView;
    self.rightView = [self.datasource nextView: self.bounds];
    
    [self addSubview:self.rightView];

    [self placeView:self.rightView X:self.frame.size.width Y:self.rightView.frame.origin.y];
    
    _direction = LEFT;
    if ([_delegate respondsToSelector: @selector(willPageFrom:toView:)]) {
        [_delegate willPageFrom:self.leftView toView:self.centerView];
    }
    
    return YES;
}

- (void) positionViews
{
    CGFloat currentCenterX = self.centerView.frame.origin.x;
    
    [self placeView:self.leftView X:-(self.frame.size.width + _pageGap) Y:self.leftView.frame.origin.y];
    [self placeView:self.centerView X:0.0 Y:self.centerView.frame.origin.y];
    [self placeView:self.rightView X:(self.frame.size.width + _pageGap) Y:self.rightView.frame.origin.y];
    
    CGFloat diff = self.centerView.frame.origin.x - currentCenterX;
    CGFloat newBgXOffset = self.bgView.frame.origin.x + diff * _parallaxFactor;
    
    [self placeView:self.bgView X:newBgXOffset Y:self.bgView.frame.origin.y];
}

- (void) positionViewsWithVelocity: (CGPoint) velocity changePage:(BOOL)changePage
{
    CGFloat points2move = fabs(self.centerView.frame.origin.x);
    CGFloat duration = points2move / fabs(velocity.x);
    duration = MIN(duration, MAX_ANIMATION_DURATION);
    
    [self positionViewsWithDuration: duration changePage:changePage];
}

- (void) positionViewsWithDuration: (CGFloat) duration changePage:(BOOL)changePage
{
    UIViewAnimationOptions options = UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState;
    
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        [self positionViews];
    } completion:^(BOOL finished) {
        if (changePage) {
            [self notifyDelegate];
        }
    }];
}

- (void) preparePagedViews
{
    for (UIView *view in [self subviews]) {
        [view removeFromSuperview];
    }
    
	self.centerView = [self.datasource currentView: self.bounds];
    [self addSubview:self.centerView];
    
    self.leftView = [self.datasource previousView: self.bounds];
    [self addSubview:self.leftView];

	self.rightView = [self.datasource nextView: self.bounds];
    [self addSubview:self.rightView];
}

- (void) notifyDelegate
{
    if ([_delegate respondsToSelector: @selector(didPageFrom:toView:)]) {
        if (_direction == RIGHT) {
            [_delegate didPageFrom:self.rightView toView:self.centerView];
        } else if (_direction == LEFT) {
            [_delegate didPageFrom:self.leftView toView:self.centerView];
        }
    }
}

- (CGSize) sizeThatFits:(CGSize)size
{
    return [self.centerView sizeThatFits:size];
}

@end
