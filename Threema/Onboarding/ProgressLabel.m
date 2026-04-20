#import "ProgressLabel.h"
#import "BundleUtil.h"

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
    _activityIndicatior.color = UIColor.whiteColor;
    _activityIndicatior.hidden = YES;
    
    _activityIndicatior.frame = [self rect:_activityIndicatior.frame centerVerticalIn:self.bounds round:YES];
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
    CGRect labelFrame = CGRectMake(self.bounds.origin.x + maxX, self.bounds.origin.y, self.bounds.size.width - maxX, self.bounds.size.height);
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
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.whiteColor, UIColor.systemGreenColor]];
        image = [UIImage systemImageNamed:imageName withConfiguration:config];
    }
    else if ([imageName isEqualToString:@"exclamationmark.circle.fill"]) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.whiteColor, UIColor.systemRedColor]];
        image = [UIImage systemImageNamed:imageName withConfiguration:config];
    }
    if (_statusView == nil) {
        _statusView = [[UIImageView alloc] initWithImage:image];
        _statusView.frame = [self growRect:_activityIndicatior.frame byDx:-6.0 byDy:-6.0];
        [self addSubview:_statusView];
    } else {
        _statusView.image = image;
    }
            
    if (CGRectIntersectsRect(_label.frame, _statusView.frame)) {
        CGFloat maxX = CGRectGetMaxX(_statusView.frame) + ACTIVITY_INDICATOR_PADDING;
        CGRect labelFrame = CGRectMake(self.bounds.origin.x + maxX, self.bounds.origin.y, self.bounds.size.width - maxX, self.bounds.size.height);
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

#pragma mark - RectUtil

- (CGRect)rect:(CGRect)rect centerVerticalIn:(CGRect)outerRect round:(BOOL)round {
    CGFloat innerHeight = rect.size.height;
    CGFloat outerHeight = outerRect.size.height;
    
    CGFloat x = rect.origin.x;
    CGFloat y = (outerHeight - innerHeight) / 2.0;
    if (round)
        y = roundf(y);
    
    return CGRectMake(x, y, rect.size.width, rect.size.height);
}

- (CGRect)growRect:(CGRect)rect byDx:(CGFloat)dX byDy:(CGFloat)dY{
    CGFloat x = rect.origin.x - dX / 2.0;
    CGFloat y = rect.origin.y - dY / 2.0;
    CGFloat width = rect.size.width + dX;
    CGFloat height = rect.size.height + dY;
    
    return CGRectMake(x, y, width, height);
}

@end
