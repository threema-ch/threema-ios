#import <UIKit/UIKit.h>

@interface ProgressLabel : UIView

@property UIFont *font;
@property UIColor *textColor;
@property NSString *text;
@property NSInteger numberOfLines;

- (void)showActivityIndicator;
- (void)hideActivityIndicator;

- (void)showErrorMessage:(NSString *)errorMessage;

- (void)showSuccessMessage:(NSString *)successMessage;

@end
