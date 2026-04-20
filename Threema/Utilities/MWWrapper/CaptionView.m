#import "CaptionView.h"
#import "MediaBrowserFile.h"
#import "Threema-Swift.h"

static const CGFloat labelPadding = 10.0;
static const CGFloat defaultCustomViewHeight = 24.0;

@interface CaptionView ()

@property BaseMessageEntity *message;
@property UIView *customView;
@property UILabel *timeLabel;

@end

@implementation CaptionView

-(id)initWithPhoto:(id<MWPhoto>)photo {
    self = [super initWithPhoto:photo];
    if (self) {
        if ([photo respondsToSelector:@selector(sourceReference)]) {
            _message = [photo performSelector:@selector(sourceReference)];
            
            if (@available(iOS 26.0, *)) {
                UIGlassEffect *glassEffect = [[UIGlassEffect alloc] init];
                UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:glassEffect];
                glassView.frame =  CGRectMake(labelPadding, labelPadding, self.bounds.size.width - labelPadding*2, defaultCustomViewHeight);
                glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                glassView.layer.cornerRadius = 20;
                glassView.clipsToBounds = NO;
                                
                CGRect customViewRect = CGRectMake(labelPadding, labelPadding, self.bounds.size.width-labelPadding*2, defaultCustomViewHeight);
                _customView = [self customViewInRect:customViewRect];
                [glassView.contentView addSubview:_customView];
                
                CGRect timeLabelRect = CGRectMake(0, CGRectGetMaxY(customViewRect) + labelPadding, customViewRect.size.width, customViewRect.size.height);
                _timeLabel = [self createLabelInRect:timeLabelRect];
                [_timeLabel setText: [DateFormatter shortStyleDateTime:_message.remoteSentDate]];
                [glassView.contentView addSubview:_timeLabel];
                
                [self addSubview:glassView];
                
                // adapt to height of resulting custom view
                if (_customView.frame.size.height != defaultCustomViewHeight) {
                    _timeLabel.frame = CGRectMake(_timeLabel.frame.origin.x, CGRectGetMaxY(_customView.frame) + labelPadding, _timeLabel.frame.size.width, _timeLabel.frame.size.height + labelPadding);
                    _customView.frame = CGRectMake(labelPadding, labelPadding, self.bounds.size.width-labelPadding*4, _customView.frame.size.height);
                    glassView.frame = CGRectMake(glassView.frame.origin.x, glassView.frame.origin.y, glassView.frame.size.width, CGRectGetMaxY(_timeLabel.frame));
                    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, CGRectGetMaxY(_timeLabel.frame));
                }
            }
            else {
                CGRect customViewRect = CGRectMake(labelPadding, labelPadding, self.bounds.size.width-labelPadding*2, defaultCustomViewHeight);
                _customView = [self customViewInRect:customViewRect];
                [self addSubview:_customView];
                
                CGRect timeLabelRect = CGRectMake(customViewRect.origin.x, CGRectGetMaxY(customViewRect) + labelPadding, customViewRect.size.width, customViewRect.size.height);
                _timeLabel = [self createLabelInRect:timeLabelRect];
                [_timeLabel setText: [DateFormatter shortStyleDateTime:_message.remoteSentDate]];
                [self addSubview:_timeLabel];
                
                // adapt to height of resulting custom view
                if (_customView.frame.size.height != defaultCustomViewHeight) {
                    _timeLabel.frame = CGRectMake(_timeLabel.frame.origin.x, CGRectGetMaxY(_customView.frame), _timeLabel.frame.size.width, _timeLabel.frame.size.height);
                    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, CGRectGetMaxY(_timeLabel.frame));
                }
            }
        }
    }
    
    self.userInteractionEnabled = YES;
    
    return self;
}

- (void)setupCaption {
    ;//    ignore
}

-(CGSize)sizeThatFits:(CGSize)size {
    CGSize labelSize = CGSizeMake(size.width, CGRectGetMaxY(_timeLabel.frame) + labelPadding);
    return labelSize;
}

- (UIView *)customViewInRect:(CGRect)rect {
    return nil;
}

- (UILabel *)createLabelInRect:(CGRect)rect {
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.opaque = NO;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    
    label.numberOfLines = 1;
    ///***** BEGIN THREEMA MODIFICATION*********
    label.textColor = [UIColor secondaryLabelColor];
    ///***** END THREEMA MODIFICATION *********
    label.font = [UIFont systemFontOfSize:17];
    
    return label;
}

- (UITextView *)createTextViewInRect:(CGRect)rect {
    UITextView *textView = [[UITextView alloc] initWithFrame:rect];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    textView.opaque = NO;
    textView.backgroundColor = [UIColor clearColor];
    textView.textAlignment = NSTextAlignmentCenter;
    ///***** BEGIN THREEMA MODIFICATION*********
    textView.textColor = [UIColor labelColor];
    ///***** END THREEMA MODIFICATION *********
    textView.font = [UIFont systemFontOfSize:17.0];
        
    return textView;    
}

@end
