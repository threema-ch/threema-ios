#import "VideoCaptionView.h"
#import "Threema-Swift.h"

@implementation VideoCaptionView

- (UIView *)customViewInRect:(CGRect)rect {
    UIView *view = [[UIView alloc] initWithFrame:rect];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIImage *tmpImage = [UIImage imageNamed:@"threema.video.fill"];
    UIImage *cameraImage = [tmpImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:cameraImage];
    imageView.tintColor = [UIColor secondaryLabelColor];

    imageView.frame = [self rect:imageView.frame centerVerticalIn:rect round:NO];
    if (@available(iOS 26.0, *)) {
        imageView.frame = CGRectMake(imageView.frame.origin.x, imageView.frame.origin.y - 10.0, imageView.frame.size.width, imageView.frame.size.height);
    }
    [view addSubview:imageView];
    
    UILabel *label = [self createLabelInRect:rect];
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    label.textAlignment = NSTextAlignmentRight;

    int seconds = ((VideoMessageEntity *)self.message).duration.intValue;
    int minutes = (seconds / 60);
    seconds -= minutes * 60;
    label.text = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    
    [label sizeToFit];
    label.frame = [self rect:label.frame centerVerticalIn:rect round:YES];
    if (@available(iOS 26.0, *)) {
        label.frame = CGRectMake(rect.size.width - label.frame.size.width - 20.0 - 10.0, label.frame.origin.y - 10.0, label.frame.size.width, label.frame.size.height);
    }
    else {
        label.frame = CGRectMake(rect.size.width - label.frame.size.width, label.frame.origin.y, label.frame.size.width, label.frame.size.height);
    }

    [view addSubview:label];

    return view;
}

- (CGRect)rect:(CGRect)rect centerVerticalIn:(CGRect)outerRect round:(BOOL)round {
    CGFloat innerHeight = rect.size.height;
    CGFloat outerHeight = outerRect.size.height;
    
    CGFloat x = rect.origin.x;
    CGFloat y = (outerHeight - innerHeight) / 2.0;
    if (round)
        y = roundf(y);
    
    return CGRectMake(x, y, rect.size.width, rect.size.height);
}

@end
