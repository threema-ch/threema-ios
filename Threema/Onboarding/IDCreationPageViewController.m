#import "IDCreationPageViewController.h"
#import "AppDelegate.h"

@interface IDCreationPageViewController ()

@property UIView *infoIconView;

@end

@implementation IDCreationPageViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    CGRect mainRect = _mainContentView.frame;
    
    if ([AppDelegate hasBottomSafeAreaInsets]) {
        mainRect.size.height -= 20.0;
    }
    
    // stick to lower left corner of main view
    CGRect rect = CGRectMake(CGRectGetMinX(mainRect), CGRectGetMaxY(mainRect), _moreView.frame.size.width, _moreView.frame.size.height);
    _moreView.frame = rect;

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMoreMessage:)];
    [_moreView addGestureRecognizer:tapGesture];
    _moreView.userInteractionEnabled = YES;
    [_moreView.okButton addTarget:self action:@selector(tappedMoreMessage:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    CGRect mainRect = _mainContentView.frame;
        
    if ([AppDelegate hasBottomSafeAreaInsets]) {
        mainRect.size.height -= 20.0;
    }
    
    // stick to lower left corner of main view
    CGRect rect = CGRectMake(CGRectGetMinX(mainRect), CGRectGetMaxY(mainRect), _moreView.frame.size.width, _moreView.frame.size.height);
    _moreView.frame = rect;
}

- (void)adaptToSmallScreen {
    CGRect rect = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y - 28.0, self.view.frame.size.width, self.view.frame.size.height);
    self.view.frame = rect;
}

- (BOOL)shouldAdaptToSmallScreen {
    return self.view.frame.size.height <= 667.0;
}

- (void)showMessageView:(UIView *)messageView {
    messageView.alpha = 0.0;
    messageView.hidden = NO;
    
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^{
        _mainContentView.alpha = 0.0;
        messageView.alpha = 1.0;
        _moreView.alpha = 0.0;
        
        [self.containerDelegate hideControls:YES];
    } completion:^(BOOL finished) {
        _mainContentView.hidden = YES;
        messageView.hidden = NO;
        
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, messageView);
    }];
}

- (void)hideMessageView:(UIView *)messageView {
    [self hideMessageView:messageView ignoreControls:NO];
}

- (void)hideMessageView:(UIView *)messageView ignoreControls:(BOOL)ignoreControls {
    _mainContentView.alpha = 0.0;
    _mainContentView.hidden = NO;
    
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^{
        messageView.alpha = 0.0;
        _mainContentView.alpha = 1.0;
        _moreView.alpha = 1.0;
        if (ignoreControls == NO) {
            [self.containerDelegate hideControls:NO];
        }
    } completion:^(BOOL finished) {
        messageView.hidden = YES;
        _mainContentView.hidden = NO;
        
    }];
}

#pragma mark - UITapGestureRecognizer

- (void)tappedMoreMessage:(UITapGestureRecognizer *)sender
{
    [self.containerDelegate hideControls: (_moreView.isShown == NO)];

    if (sender.state == UIGestureRecognizerStateEnded || [sender isKindOfClass:[UIButton class]]) {
        [_moreView toggle];
    }
}


@end
