//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define MAX_ANIMATION_DURATION 0.3
#define MIN_PAGE_PAN_POINTS 50.0
#define MIN_PAGE_PAN_SPEED 150.0
#define DEFAULT_PAGE_GAP 5.0
#define DEFAULT_PARALLAX_FACTOR 1.0/10.0

typedef enum PagingDirection {
    LEFT,
    RIGHT
} PagingDirection;

@protocol PageViewDataSource

- (UIView *) currentView: (CGRect) frame;
- (UIView *) nextView: (CGRect) frame;
- (UIView *) previousView: (CGRect) frame;

- (BOOL) moveToPrevious;
- (BOOL) moveToNext;

@end

@protocol PageViewDelegate

- (void) willPageFrom: (UIView *) fromView toView: (UIView *) toView;
- (void) didPageFrom: (UIView *) fromView toView: (UIView *) toView;
@end

@interface PageView : UIView

@property (nonatomic) id<PageViewDataSource> datasource;

@property (weak, nonatomic) NSObject<PageViewDelegate> *delegate;

@property (nonatomic) UIView *bgView;

@property (nonatomic) UIView *centerView;
@property (nonatomic) UIView *leftView;
@property (nonatomic) UIView *rightView;

@property CGFloat pageGap;

@property CGFloat parallaxFactor;

- (void) resetPageFrames;

- (void) reset;

- (void) pageRight;

- (void) pageLeft;

- (void) enablePanGesture:(BOOL)enablePan;

@end


