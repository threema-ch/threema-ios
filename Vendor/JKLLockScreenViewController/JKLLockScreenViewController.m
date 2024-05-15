// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

// See Resources/License.html for original license

#import "JKLLockScreenViewController.h"
#import "JKLLockScreenPincodeView.h"
#import "JKLLockScreenNumber.h"

#import <AudioToolbox/AudioToolbox.h>
#import <LocalAuthentication/LocalAuthentication.h>

//------------------ Threema edit begin ---------------------------
#import "BundleUtil.h"
#import "LicenseStore.h"
#import "AppGroup.h"
#import "KKPasscodeLock.h"
#import "KKKeychain.h"
#import "UIImage+ColoredImage.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"
//------------------ Threema edit end ---------------------------

static const NSTimeInterval LSVSwipeAnimationDuration = 0.3f;
static const NSTimeInterval LSVDismissWaitingDuration = 0.4f;
static const NSTimeInterval LSVShakeAnimationDuration = 0.5f;

static const NSUInteger oldMaxLength = 4;
static const NSUInteger newMaxLength = 6;

//------------------ Threema edit begin ---------------------------
@interface JKLLockScreenViewController()<JKLLockScreenPincodeViewDelegate, UITextFieldDelegate> {
//------------------ Threema edit end ---------------------------
    
    NSString * _confirmPincode;
    LockScreenMode _prevLockScreenMode;
    
    //------------------ Threema edit begin ---------------------------
    NSInteger _failedAttemptsCount;
    BOOL _eraseData;
    BOOL _passcodeLockOn;
    BOOL _sameAsOldPassword;
    //------------------ Threema edit end ---------------------------
}

@property (nonatomic, weak) IBOutlet UILabel  * titleLabel;
@property (nonatomic, weak) IBOutlet UILabel  * subtitleLabel;
@property (nonatomic, weak) IBOutlet UIButton * cancelButton;
@property (nonatomic, weak) IBOutlet UIButton * deleteButton;
//------------------ Threema edit begin ---------------------------
@property (nonatomic, weak) IBOutlet UITextField *textField;
@property (nonatomic, weak) IBOutlet UIImageView *threemaLogo;
@property (nonatomic, weak) IBOutlet UIButton *eraseDataButton;
//------------------ Threema edit end ---------------------------
@property (strong, nonatomic) IBOutletCollection(JKLLockScreenNumber) NSArray *numberButtons;

@property (nonatomic, weak) IBOutlet JKLLockScreenPincodeView * pincodeView;

@end


@implementation JKLLockScreenViewController

//------------------ Threema edit begin ---------------------------
- (void)loadView {
    [super loadView];
    
    _failedAttemptsCount = [[AppGroup userDefaults] integerForKey:@"FailedCodeAttempts"];
}

- (void)viewWillAppear:(BOOL)animated {
    [_pincodeView initPincode];
    [super viewWillAppear:animated];
    //------------------ Threema edit begin ---------------------------
    [_cancelButton setTitle:[BundleUtil localizedStringForKey:@"cancel"] forState:UIControlStateNormal];
    [_deleteButton setTitle:[BundleUtil localizedStringForKey:@"delete"] forState:UIControlStateNormal];
    [_eraseDataButton setTitle:KKPasscodeLockLocalizedString(@"Erase Data", @"") forState:UIControlStateNormal];
    //------------------ Threema edit end ---------------------------
    
    _passcodeLockOn = [[KKKeychain getStringForKey:@"passcode_on"] isEqualToString:@"YES"];
    _eraseData = [[KKPasscodeLock sharedLock] eraseOption] && [[KKKeychain getStringForKey:@"erase_data_on"] isEqualToString:@"YES"];
    
    _titleLabel.textColor = Colors.textLockScreen;
    _titleLabel.shadowColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.6];
    _subtitleLabel.textColor = Colors.textLockScreen;
    _subtitleLabel.shadowColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.6];
    [_eraseDataButton setTitleColor:Colors.red forState:UIControlStateNormal];
    [_eraseDataButton setTitleShadowColor:[UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.6] forState:UIControlStateNormal];
    [self.view setBackgroundColor:Colors.backgroundView];
    
    //------------------ Threema edit begin ---------------------------
    _threemaLogo.image = [Colors threemaLogoForPasscode];
    //------------------ Threema edit end ---------------------------
    
    [Colors updateWithNavigationBar:self.navigationController.navigationBar];
    
    _pincodeView.pincodeColor = UIColor.primary;
    _tintColor = UIColor.primary;
    [self tintSubviewsWithColor:_tintColor];
}
//------------------ Threema edit end ---------------------------


- (void)viewDidLoad {
    [super viewDidLoad];
    //------------------ Threema edit begin ---------------------------
    _cancelButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    _deleteButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [_threemaLogo addGestureRecognizer:lpgr];
    
    switch (_lockScreenMode) {
        case LockScreenModeVerification:
        case LockScreenModeNormal: {
            // [일반 모드] Cancel 버튼 감춤
            [_cancelButton setHidden:YES];
            [_eraseDataButton setHidden:YES];
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter your passcode", @"")];
            [self lsv_updateSubtitle:nil];
            _threemaLogo.userInteractionEnabled = YES;
            _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
            break;
        }
        case LockScreenModeExtension: {
            // [일반 모드] Cancel 버튼 감춤
            [_cancelButton setHidden:NO];
            [_eraseDataButton setHidden:YES];
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter your passcode", @"")];
            [self lsv_updateSubtitle:nil];
            _threemaLogo.userInteractionEnabled = YES;
            _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
            break;
        }
        case LockScreenModeNew: {
            // [신규 모드]
            [_eraseDataButton setHidden:YES];
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter a passcode", @"")];
            [self lsv_updateSubtitle:nil];
            _threemaLogo.userInteractionEnabled = NO;
            [_textField resignFirstResponder];
            _pincodeView.maxPincodeLength = newMaxLength;
            break;
        }
        case LockScreenModeChange:
            [_eraseDataButton setHidden:YES];
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter your new passcode", @"")];
            [self lsv_updateSubtitle:nil];
            _threemaLogo.userInteractionEnabled = YES;
            _pincodeView.maxPincodeLength = newMaxLength;
            break;
        case LockScreenModeChangeCheck:
            [_eraseDataButton setHidden:YES];
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter your old passcode", @"")];
            [self lsv_updateSubtitle:nil];
            _threemaLogo.userInteractionEnabled = YES;
            _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
            break;

        case LockScreenModeDisable:
            [_eraseDataButton setHidden:YES];
            [_cancelButton setHidden:NO];
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter your passcode", @"")];
            [self lsv_updateSubtitle:nil];
            _threemaLogo.userInteractionEnabled = YES;
            _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
            break;
    }
    [_pincodeView setNeedsDisplay];
    
    //------------------ Threema edit end ---------------------------
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // [일반모드] 였을 경우
    BOOL isModeNormal = (_lockScreenMode == LockScreenModeNormal || _lockScreenMode == LockScreenModeExtension);
    if (isModeNormal && [_delegate respondsToSelector:@selector(allowTouchIDLockScreenViewController:)]) {
        if ([_dataSource allowTouchIDLockScreenViewController:self]) {
            // Touch ID 암호 입력창 호출
            [self lsv_policyDeviceOwnerAuthentication];
        }
    }
}

/**
 *  Changes buttons tint color
 *
 *  @param color tint color for buttons
 */
- (void)tintSubviewsWithColor: (UIColor *) color{
    [_cancelButton setTitleColor:color forState:UIControlStateNormal];
    [_deleteButton setTitleColor:color forState:UIControlStateNormal];
    [_pincodeView setPincodeColor:color];
    
    for (JKLLockScreenNumber * number in _numberButtons)
    {
        [number setTintColor:color];
        [number setTitleColor:Colors.textLockScreen forState:UIControlStateNormal];
    }
}

/**
 Touch ID 창을 호출하는 메소드
 */
- (void)lsv_policyDeviceOwnerAuthentication {
    
    NSError   * error   = nil;
    LAContext * context = [[LAContext alloc] init];
    
    // check if the policy can be evaluated
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        // evaluate
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason:NSLocalizedStringFromTable(@"Pincode TouchID", @"JKLockScreen", nil)
                          reply:^(BOOL success, NSError * authenticationError) {
                              if (success) {
                                  [self lsv_unlockDelayDismissViewController:LSVDismissWaitingDuration];
                              }
                              else {
                                  NSLog(@"LAContext::Authentication Error : %@", authenticationError);
                              }
                          }];
    }
    else {
        NSLog(@"LAContext::Policy Error : %@", [error localizedDescription]);
    }
    
}

/**
 일정 시간 딜레이 후 창을 dismiss 하는 메소드
 @param NSTimeInterval 딜레이 시간
 */
- (void)lsv_unlockDelayDismissViewController:(NSTimeInterval)delay {
    __weak id weakSelf = self;
    
    [_pincodeView wasCompleted];
    
    // 인증이 완료된 후 창이 dismiss될 때
    // 너무 빨리 dimiss되면 잔상처럼 남으므로 일정시간 딜레이 걸어서 dismiss 함
    dispatch_time_t delayInSeconds = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(delayInSeconds, dispatch_get_main_queue(), ^(void){
        [self dismissViewControllerAnimated:NO completion:^{
            if ([_delegate respondsToSelector:@selector(unlockWasSuccessfulLockScreenViewController:)]) {
                [_delegate unlockWasSuccessfulLockScreenViewController:weakSelf];
            }
            if ([_delegate respondsToSelector:@selector(didPasscodeEnteredCorrectly:)]) {
                [_delegate didPasscodeEnteredCorrectly:weakSelf];
            }
        }];
    });
}

/**
 핀코드가 일치하는지 반판하는 메소드: [확인모드]와 [일반모드]가 다르다
 @param  NSString PIN code
 @return BOOL 암호 유효성
 */
- (BOOL)lsv_isPincodeValid:(NSString *)pincode {
    //------------------ Threema edit begin ---------------------------
//    // [확인모드]일 경우, Confirm Pincode와 비교
//    if (_lockScreenMode == LockScreenModeVerification) {
//        return [_confirmPincode isEqualToString:pincode];
//    }
//    
//    // [신규모드], [변경모드]일 경우 기존 Pincode와 비교
//    return [_dataSource lockScreenViewController:self pincode:pincode];
    //------------------ Threema edit end ---------------------------
    
    
    //------------------ Threema edit begin ---------------------------
    if (_lockScreenMode == LockScreenModeNormal || _lockScreenMode == LockScreenModeExtension || _lockScreenMode == LockScreenModeDisable || _lockScreenMode == LockScreenModeChangeCheck) {
        NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
        return [pincode isEqualToString:passcode];
    }
    else if (_lockScreenMode == LockScreenModeChange) {
        NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
        return ![passcode isEqualToString:pincode];
    }
    else if (_lockScreenMode == LockScreenModeVerification) {
        return [pincode isEqualToString:_confirmPincode];
    }
    return NO;
    //------------------ Threema edit end ---------------------------
}

/**
 타이틀과 서브타이틀을 변경하는 메소드
 @param NSString 주 제목
 @param NSString 서브 제목
 */
- (void)lsv_updateTitle:(NSString *)title {
    [_titleLabel setText:title];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (void)lsv_updateSubtitle:(NSString *)subtitle {
    [_subtitleLabel setText:subtitle];
    
    if(subtitle != nil) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.subtitleLabel);
    }
}

/**
 잠금 해제에 성공했을 경우 발생하는 메소드
 @param NSString PIN code
 */
- (void)lsv_unlockScreenSuccessful:(NSString *)pincode {
    [self dismissViewControllerAnimated:YES completion:^{
        if ([_delegate respondsToSelector:@selector(unlockWasSuccessfulLockScreenViewController:pincode:)]) {
            [_delegate unlockWasSuccessfulLockScreenViewController:self pincode:pincode];
        }
        //------------------ Threema edit begin ---------------------------
        if ([_delegate respondsToSelector:@selector(didPasscodeViewDismiss:)]) {
            [_delegate performSelector:@selector(didPasscodeViewDismiss:) withObject:self];
        }
        //------------------ Threema edit end ---------------------------
    }];
}

/**
 잠금 해제에 실패했을 경우 발생하는 메소드
 */
- (void)lsv_unlockScreenFailure {
    if (_lockScreenMode != LockScreenModeVerification) {
        if ([_delegate respondsToSelector:@selector(unlockWasFailureLockScreenViewController:)]) {
            [_delegate unlockWasFailureLockScreenViewController:self];
        }
    }
    
    // 디바이스 진동
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    // make shake animation
    CAAnimation * shake = [self lsv_makeShakeAnimation];
    [_pincodeView.layer addAnimation:shake forKey:@"shake"];
    [_pincodeView setEnabled:NO];
    //------------------ Threema edit begin ---------------------------
    [self lsv_updateSubtitle:KKPasscodeLockLocalizedString(@"Passcodes did not match. Try again.", @"")];
    //------------------ Threema edit end ---------------------------
    dispatch_time_t delayInSeconds = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LSVShakeAnimationDuration * NSEC_PER_SEC));
    dispatch_after(delayInSeconds, dispatch_get_main_queue(), ^(void){
        [_pincodeView setEnabled:YES];
        [_pincodeView initPincode];
        
        switch (_lockScreenMode) {
                //------------------ Threema edit begin ---------------------------
            case LockScreenModeChangeCheck:
            case LockScreenModeExtension:
            case LockScreenModeNormal: {
                _failedAttemptsCount += 1;
                _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
                if (_failedAttemptsCount == 1) {
                    [self lsv_updateSubtitle:KKPasscodeLockLocalizedString(@"1 Failed Passcode Attempt", @"")];
                } else {
                    [self lsv_updateSubtitle:[NSString stringWithFormat:KKPasscodeLockLocalizedString(@"%i Failed Passcode Attempts", @""), (long)_failedAttemptsCount]];
                }
                
                if (_failedAttemptsCount >= [[KKPasscodeLock sharedLock] attemptsAllowed]) {
                    
                    if (_eraseData) {
                        if ([_delegate respondsToSelector:@selector(shouldEraseApplicationData:)]) {
                            [_delegate shouldEraseApplicationData:self];
                        }
                    } else {
                        if ([_delegate respondsToSelector:@selector(didPasscodeEnteredIncorrectly:)]) {
                            [_delegate didPasscodeEnteredIncorrectly:self];
                        }
                        if (_lockScreenMode == LockScreenModeNormal) {
                            _eraseDataButton.hidden = NO;
                        }
                        /* show "erase data" button to give user a chance to reset app if he forgets the passphrase */
//                        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:KKPasscodeLockLocalizedString(@"Erase Data", @"") style:UIBarButtonItemStylePlain target:self action:@selector(eraseDataButtonPressed)];
                    }
                } else {
                    [[AppGroup userDefaults] setInteger:_failedAttemptsCount forKey:@"FailedCodeAttempts"];
                    [[AppGroup userDefaults] synchronize];
                }
                _threemaLogo.userInteractionEnabled = YES;

                break;
            }
            case LockScreenModeNew: {
                _pincodeView.maxPincodeLength = newMaxLength;
                [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter a passcode", @"")];
                [self lsv_updateSubtitle:nil];
                _threemaLogo.userInteractionEnabled = NO;
                [_textField resignFirstResponder];
                break;
            }
            case LockScreenModeChange:
                _pincodeView.maxPincodeLength = newMaxLength;
                [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter your new passcode", @"")];
                if (_sameAsOldPassword) {
                    [self lsv_updateSubtitle:KKPasscodeLockLocalizedString(@"Enter a different passcode. You cannot re-use the same passcode.", @"")];
                } else {
                    [self lsv_updateSubtitle:KKPasscodeLockLocalizedString(@"Passcodes did not match. Try again.", @"")];
                }
                _threemaLogo.userInteractionEnabled = NO;
                [_textField resignFirstResponder];
                break;
            default:
                break;
        }
        //------------------ Threema edit end ---------------------------
    });
}

/**
 쉐이크 에니메이션을 생성하는 메소드
 @return CAAnimation
 */
- (CAAnimation *)lsv_makeShakeAnimation {
    
    CAKeyframeAnimation * shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    [shake setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [shake setDuration:LSVShakeAnimationDuration];
    [shake setValues:@[ @(-20), @(20), @(-20), @(20), @(-10), @(10), @(-5), @(5), @(0) ]];
    
    return shake;
}

/**
 서브 타이틀과 PincodeView를 애니메이션 하는 메소드
 ! PincodeView는 제약이 서브타이틀과 같이 묶여 있으므로 따로 해주지 않아도 됨
 1차 : 화면 왼쪽 끝으로 이동 with Animation
 2차 : 화면 오른쪽 끝으로 이동 without Animation
 3차 : 화면 가운데로 이동 with Animation
 */
- (void)lsv_swipeSubtitleAndPincodeView {
    
    __weak UIView * weakView = self.view;
    __weak UIView * weakCode = _pincodeView;
    
    [(id)weakCode setEnabled:NO];
    
    CGFloat width = CGRectGetWidth([self view].bounds);
    NSLayoutConstraint * centerX = [self lsv_findLayoutConstraint:weakView  childView:_subtitleLabel attribute:NSLayoutAttributeCenterX];
    
    centerX.constant = width;
    [UIView animateWithDuration:LSVSwipeAnimationDuration animations:^{
        [weakView layoutIfNeeded];
    } completion:^(BOOL finished) {
        
        [(id)weakCode initPincode];
        centerX.constant = -width;
        [weakView layoutIfNeeded];
        
        centerX.constant = 0;
        [UIView animateWithDuration:LSVSwipeAnimationDuration animations:^{
            [weakView layoutIfNeeded];
        } completion:^(BOOL finished) {
            [(id)weakCode setEnabled:YES];
        }];
    }];
}

#pragma mark -
#pragma mark NSLayoutConstraint
- (NSLayoutConstraint *)lsv_findLayoutConstraint:(UIView *)superview childView:(UIView *)childView attribute:(NSLayoutAttribute)attribute {
    for (NSLayoutConstraint * constraint in superview.constraints) {
        if (constraint.firstItem == superview && constraint.secondItem == childView && constraint.firstAttribute == attribute) {
            return constraint;
        }
    }
    
    return nil;
}

#pragma mark -
#pragma mark IBAction
- (IBAction)onNumberClicked:(id)sender {
    
    NSInteger number = [((UIButton *)sender) tag];
    [_pincodeView appendingPincode:[@(number) description]];
}

- (IBAction)onCancelClicked:(id)sender {
    
    if ([_delegate respondsToSelector:@selector(unlockWasCancelledLockScreenViewController:)]) {
        [_delegate unlockWasCancelledLockScreenViewController:self];
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)onDeleteClicked:(id)sender {
    
    [_pincodeView removeLastPincode];
}

//------------------ Threema edit begin ---------------------------
- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        if (_textField.isFirstResponder) {
            [_textField resignFirstResponder];
        } else {
            [_textField becomeFirstResponder];
        }
    }
}

- (IBAction)onEraseDataClicked:(id)sender {
    [self eraseDataButtonPressed];
}
//------------------ Threema edit end ---------------------------

#pragma mark -
#pragma mark JKLLockScreenPincodeViewDelegate
- (void)lockScreenPincodeView:(JKLLockScreenPincodeView *)lockScreenPincodeView pincode:(NSString *)pincode {
    //------------------ Threema edit begin ---------------------------
    if (_lockScreenMode == LockScreenModeDisable) {
        _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
        if ([self lsv_isPincodeValid:pincode]) {
            if ([KKKeychain setString:@"NO" forKey:@"passcode_on"]) {
                [KKKeychain setString:@"" forKey:@"passcode"];
            }
            
            if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
                [_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
            }
            
            [[AppGroup userDefaults] setInteger:0 forKey:@"FailedCodeAttempts"];
            [[AppGroup userDefaults] synchronize];
            
            ConversationStore * conversationStore = [[BusinessInjector new] conversationStoreObjC];
            [conversationStore unmarkAllPrivateConversations];
            
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self lsv_unlockScreenFailure];
        }
    } else if (_lockScreenMode == LockScreenModeNormal || _lockScreenMode == LockScreenModeExtension) {
        // [일반 모드]
        _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
        if ([self lsv_isPincodeValid:pincode]) {
            [[KKPasscodeLock sharedLock] updateLastUnlockTime];
            if ([_delegate respondsToSelector:@selector(didPasscodeEnteredCorrectly:)]) {
                [_delegate performSelector:@selector(didPasscodeEnteredCorrectly:) withObject:self];
            }
            
            [[AppGroup userDefaults] setInteger:0 forKey:@"FailedCodeAttempts"];
            [[AppGroup userDefaults] synchronize];
            _failedAttemptsCount = 0;
            [self lsv_updateSubtitle:nil];
            [_pincodeView initPincode];
            [self lsv_unlockScreenSuccessful:pincode];
        }
        else {
            [self lsv_unlockScreenFailure];
        }
    } else if (_lockScreenMode == LockScreenModeVerification) {
        _pincodeView.maxPincodeLength = [self is4DigitCodeSet] ? oldMaxLength : newMaxLength;
        _sameAsOldPassword = NO;
        if ([self lsv_isPincodeValid:pincode]) {
            [self setLockScreenMode:_prevLockScreenMode];
            if ([KKKeychain setString:pincode forKey:@"passcode"]) {
                [KKKeychain setString:@"YES" forKey:@"passcode_on"];
            }
            
            if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
                [_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
            }
            [self lsv_unlockScreenSuccessful:pincode];
        }
        else {
            [self setLockScreenMode:_prevLockScreenMode];
            [self lsv_unlockScreenFailure];
        }
    } else if (_lockScreenMode == LockScreenModeChangeCheck) {
        _pincodeView.maxPincodeLength = newMaxLength;
        if ([self lsv_isPincodeValid:pincode]) {
            [self setLockScreenMode:LockScreenModeChange];
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Enter your new passcode", @"")];
            [self lsv_updateSubtitle:nil];
            [self lsv_swipeSubtitleAndPincodeView];
            _threemaLogo.userInteractionEnabled = NO;
            [_textField resignFirstResponder];
        }
        else {
            [self lsv_unlockScreenFailure];
        }
    } else {
        _pincodeView.maxPincodeLength = newMaxLength;
        if (![self lsv_isPincodeValid:pincode] && _passcodeLockOn) {
            _sameAsOldPassword = YES;
            [self lsv_unlockScreenFailure];
        } else {
            _sameAsOldPassword = NO;
            _confirmPincode = pincode;
            _prevLockScreenMode = _lockScreenMode;
            [self setLockScreenMode:LockScreenModeVerification];
            // 재입력 타이틀로 전환
            [self lsv_updateTitle:KKPasscodeLockLocalizedString(@"Re-enter your new passcode", @"")];
            [self lsv_updateSubtitle:nil];
            
            _threemaLogo.userInteractionEnabled = NO;
            [_textField resignFirstResponder];
            
            // 서브타이틀과 pincodeviw 이동 애니메이션
            [self lsv_swipeSubtitleAndPincodeView];
        }
    }
    //------------------ Threema edit end ---------------------------
}

#pragma mark - 
#pragma mark LockScreenViewController Orientation

//------------------ Threema edit begin ---------------------------
-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate {
    if (SYSTEM_IS_IPAD) {
        return YES;
    }
    return YES;
}
//------------------ Threema edit end ---------------------------

//------------------ Threema edit begin ---------------------------
#pragma mark -
#pragma mark Threema functions

- (void)eraseDataButtonPressed {
    NSString *title = KKPasscodeLockLocalizedString(@"Erase all data and reset passcode", @"");
    NSString *cancel = NSLocalizedString(@"cancel", nil);
    NSString *erase = KKPasscodeLockLocalizedString(@"Erase Data", @"");

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:nil];

    UIAlertAction *eraseAction = [UIAlertAction actionWithTitle:erase style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self eraseData];
    }];

    [alertController addAction:cancelAction];
    [alertController addAction:eraseAction];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)eraseData {
    if ([_delegate respondsToSelector:@selector(shouldEraseApplicationData:)]) {
        [_delegate shouldEraseApplicationData:self];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [_pincodeView appendingPincode:newText];
    return NO;
}

- (BOOL)is4DigitCodeSet {
    NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
    return passcode.length == oldMaxLength;
}

//------------------ Threema edit end ---------------------------

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    for (JKLLockScreenNumber * number in _numberButtons) {
        [number setNeedsDisplay];
    }
    [self.pincodeView setNeedsDisplay];
}

@end
