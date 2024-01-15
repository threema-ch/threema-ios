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

#import "BallotResultMatrixCell.h"
#import "UIImage+ColoredImage.h"
#import "BallotResult.h"
#import "RectUtil.h"
#import "UIImage+ColoredImage.h"
#import "BundleUtil.h"

#define CHECKMARK_IMAGE @"Checkmark"
#define CHECKMARK_SCALE 0.4

#define MINUS_IMAGE @"Minus"
#define MINUS_VERTICAL_SCALE 0.32
#define MINUS_HORIZONTAL_SCALE 0.06

#define IMAGE_COLOR Colors.text

@implementation BallotResultMatrixCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.isAccessibilityElement = YES;
    }
    return self;
}

- (void)setBorderColor: (UIColor *)color {
    self.layer.borderColor = color.CGColor;
}

- (void)setBorderWidth: (CGFloat)width {
    self.layer.borderWidth = width;
}

- (void)setColorForChoice:(UIColor *)color {
    NSArray *subViews = self.subviews;
    [subViews enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[UIImageView class]]) {
            UIImageView *imageView = (UIImageView *)obj;
            imageView.tintColor = color;
        }
    }];
}

- (void)updateResultForChoice:(BallotChoice *)choice andParticipant:(NSString *)participant {
    BallotResult *result = [choice getResultForId: participant];
    
    if (result == nil) {
        ;//
    } else if (result.boolValue) {
        UIImageView *checkmark = [self getCheckmark];
        [self addSubview: checkmark];
        self.accessibilityValue = [BundleUtil localizedStringForKey:@"yes"];
    } else {
        UIImageView *minus = [self getMinus];
        [self addSubview: minus];
        self.accessibilityValue = [BundleUtil localizedStringForKey:@"no"];
    }
}

- (UIImageView *)getCheckmark {
    return [self getImage:CHECKMARK_IMAGE verticalScale:CHECKMARK_SCALE horizontalScale:CHECKMARK_SCALE];
}

- (UIImageView *)getMinus {
    return [self getImage:MINUS_IMAGE verticalScale:MINUS_VERTICAL_SCALE horizontalScale:MINUS_HORIZONTAL_SCALE];
}

- (UIImageView *)getImage:(NSString *)imageName verticalScale:(CGFloat)verticalScale horizontalScale:(CGFloat)horizontalScale {
    CGRect rect = CGRectMake(0.0, 0.0, self.bounds.size.width*verticalScale, self.bounds.size.height*horizontalScale);
    rect = [RectUtil rect:rect centerIn:self.bounds];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame: rect];
    UIImage *image;
    
    UIImage *tmpImage = [UIImage imageNamed:imageName];
    image = [tmpImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.tintColor = IMAGE_COLOR;
    
    [imageView setImage:image];
    
    return imageView;
}

@end
