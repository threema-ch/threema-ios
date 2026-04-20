#import "MWCaptionView.h"

@class BaseMessageEntity;

@interface CaptionView : MWCaptionView

- (UIView *)customViewInRect:(CGRect)rect;

- (UILabel *)createLabelInRect:(CGRect)rect;

- (UITextView *)createTextViewInRect:(CGRect)rect;

- (BaseMessageEntity *)message;

@end
