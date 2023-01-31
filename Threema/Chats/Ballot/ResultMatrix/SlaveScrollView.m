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

#import "SlaveScrollView.h"
#import "BallotMatrixLabelView.h"
#import "BallotResultMatrixCell.h"

@interface SlaveScrollView ()

@property ScrollViewContent *contentView;
@property CGFloat maxX;
@property CGFloat maxY;

@end

@implementation SlaveScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _horizontalScrollingEnabled = YES;

        self.clipsToBounds = YES;
        self.alwaysBounceVertical = NO;
        self.alwaysBounceHorizontal = NO;
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
    }
    
    return self;
}

- (void)setContent:(ScrollViewContent *)contentView {
    if (_contentView != contentView) {
        [_contentView removeFromSuperview];
    }
    
    _contentView = contentView;
    [self addSubview:_contentView];

    [self updateContentSize];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    [self updateContentSize];
}

- (void)updateContentSize {
    [_contentView adaptToWidth: self.frame.size.width];
    [self setContentSize: _contentView.frame.size];

    _maxX = roundf(_contentView.bounds.size.width - self.bounds.size.width);
    _maxY = roundf(_contentView.bounds.size.height - self.bounds.size.height);
}

- (CGPoint)setPosition:(CGPoint)position {
    CGFloat x = fmaxf(0.0, position.x);
    x = fminf(x, _maxX);
    
    if (_maxX < 0.0 || _horizontalScrollingEnabled == NO) {
        x = 0.0;
    }
    
    CGFloat y = fmaxf(0.0, position.y);
    y = fminf(y, _maxY);

    if (_maxY < 0.0) {
        y = 0.0;
    }

    CGPoint resultingPosition = CGPointMake(x, y);
    self.contentOffset = resultingPosition;
    
    return resultingPosition;
}

- (CGPoint)position {
    return self.contentOffset;
}

- (void)setColor:(UIColor *)color forRowAt:(NSInteger)index {
    NSArray *subviews = [self.contentView subviews];
    
    if (index < [subviews count]) {
        UIView *view = [subviews objectAtIndex:index];
        view.backgroundColor = color;
    }
}

- (void)setTextColor:(UIColor *)color forRowAt:(NSInteger)index {
    NSArray *subviews = [self.contentView subviews];
    if (index < [subviews count]) {
        UIView *view = [subviews objectAtIndex:index];
        if ([view isKindOfClass:[BallotMatrixLabelView class]] && Colors.theme == ThemeLight) {
            BallotMatrixLabelView *b = (BallotMatrixLabelView *)view;
            [b setTextColor:Colors.textInverted];
        } else {
            NSArray *subsub = [view subviews];
            [subsub enumerateObjectsUsingBlock:^(id v, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([v isKindOfClass:[BallotResultMatrixCell class]]) {
                    BallotResultMatrixCell *cell = (BallotResultMatrixCell *)v;
                    [cell setColorForChoice:Colors.textInverted];
                }
            }];
        }
    }
}

@end
