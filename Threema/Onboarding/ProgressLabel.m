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

#import "ProgressLabel.h"
#import "RectUtil.h"
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"

#define ACTIVITY_INDICATOR_PADDING 6.0
#define NUMBER_OF_LINES 2

@interface ProgressLabel ()

@property UIActivityIndicatorView *activityIndicatior;
@property UILabel *label;
@property UIImageView *statusView;

@end

@implementation ProgressLabel

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    
    return self;
}

- (void)setup {
    _activityIndicatior = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _activityIndicatior.color = Colors.textSetup;
    _activityIndicatior.hidden = YES;
    
    _activityIndicatior.frame = [RectUtil rect:_activityIndicatior.frame centerVerticalIn:self.bounds round:YES];
    [self addSubview:_activityIndicatior];
    
    _label = [[UILabel alloc] initWithFrame:self.bounds];
    _label.numberOfLines = NUMBER_OF_LINES;
    [self addSubview:_label];
}

- (void)setText:(NSString *)text {
    [_label setText:text];
}

- (NSString *)text {
    return _label.text;
}

- (void)hideActivityIndicator {
    _label.frame = self.bounds;

    [_activityIndicatior stopAnimating];
    _activityIndicatior.alpha = 0.0;
}

- (void)showActivityIndicator {
    CGFloat maxX = CGRectGetMaxX(_activityIndicatior.frame) + ACTIVITY_INDICATOR_PADDING;
    CGRect labelFrame = [RectUtil offsetAndResizeRect:self.bounds byX:maxX byY:0.0];
    _label.frame = labelFrame;
    
    [_activityIndicatior startAnimating];
    _activityIndicatior.alpha = 1.0;
}

- (void)showErrorMessage:(NSString *)errorMessage {
    if ([NSThread isMainThread]) {
        [self setStatusImage:@"exclamationmark.circle.fill"];
        _label.text = errorMessage;
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self setStatusImage:@"exclamationmark.circle.fill"];
            _label.text = errorMessage;
        });
    }
}

- (void)showSuccessMessage:(NSString *)successMessage {
    if ([NSThread isMainThread]) {
        [self setStatusImage:@"checkmark.circle.fill"];
        _label.text = successMessage;
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self setStatusImage:@"checkmark.circle.fill"];
            _label.text = successMessage;
        });
    }
}

- (void)setStatusImage:(NSString *)imageName {
    UIImage *image = [UIImage systemImageNamed:imageName];
    if (image == nil) {
        image = [BundleUtil imageNamed:imageName];
    }
    if ([imageName isEqualToString:@"checkmark.circle.fill"]) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[Colors.white, Colors.green]];
        image = [UIImage systemImageNamed:imageName withConfiguration:config];
    }
    else if ([imageName isEqualToString:@"exclamationmark.circle.fill"]) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[Colors.white, Colors.red]];
        image = [UIImage systemImageNamed:imageName withConfiguration:config];
    }
    if (_statusView == nil) {
        _statusView = [[UIImageView alloc] initWithImage:image];
        _statusView.frame = [RectUtil growRect:_activityIndicatior.frame byDx:-6.0 byDy:-6.0];
        [self addSubview:_statusView];
    } else {
        _statusView.image = image;
    }
            
    if (CGRectIntersectsRect(_label.frame, _statusView.frame)) {
        CGFloat maxX = CGRectGetMaxX(_statusView.frame) + ACTIVITY_INDICATOR_PADDING;
        CGRect labelFrame = [RectUtil offsetAndResizeRect:self.bounds byX:maxX byY:0.0];
        _label.frame = labelFrame;
    }
    
    _activityIndicatior.hidden = YES;
}

- (void)setFont:(UIFont *)font {
    _label.font = font;
}

- (UIFont *)font {
    return _label.font;
}

- (void)setTextColor:(UIColor *)textColor {
    _label.textColor = textColor;
}

- (UIColor *)textColor {
    return _label.textColor;
}

- (void)setNumberOfLines:(NSInteger)numberOfLines {
    _label.numberOfLines = numberOfLines;
}

- (NSInteger)numberOfLines {
    return _label.numberOfLines;
}

@end
