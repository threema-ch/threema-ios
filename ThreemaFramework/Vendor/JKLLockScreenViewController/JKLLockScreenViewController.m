// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema AG and licensed under the AGPLv3.

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
#import "TouchIDAuthentication.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
//------------------ Threema edit end ---------------------------

static const NSTimeInterval LSVSwipeAnimationDuration = 0.3f;
static const NSTimeInterval LSVDismissWaitingDuration = 0.4f;
static const NSTimeInterval LSVShakeAnimationDuration = 0.5f;

static const NSUInteger oldMaxLength = 4;
static const NSUInteger newMaxLength = 6;

//------------------ Threema edit begin ---------------------------
// The keypad is built in code rather than in the nib: its cells were sized there by a single chain
// of equality constraints, so anything that disturbed one cell collapsed the whole grid.
static const CGFloat LSVKeypadKeySize = 75.0f;
static const CGFloat LSVKeypadColumnSpacing = 20.0f;
static const CGFloat LSVKeypadRowSpacing = 10.0f;
static const CGFloat LSVKeypadTopSpacing = 20.0f;
static const CGFloat LSVBottomButtonSpacing = 20.0f;
static const CGFloat LSVBottomButtonInset = 10.0f;
/// Ratios the digits and the symbols occupy inside their cell
static const CGFloat LSVKeyDigitRatio = 0.47f;
static const CGFloat LSVKeySymbolRatio = 0.45f;
static const CGFloat LSVKeyBackspaceRatio = 0.36f;
//------------------ Threema edit end ---------------------------

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
    BOOL _biometricUnlockAvailable;
    BOOL _biometricAuthenticationInProgress;
    BOOL _biometricUnlockDisabled;
    NSString *_biometricSymbolName;
    CGFloat _keypadKeyHeight;
    //------------------ Threema edit end ---------------------------
}

@property (nonatomic, weak) IBOutlet UILabel  * titleLabel;
@property (nonatomic, weak) IBOutlet UILabel  * subtitleLabel;
//------------------ Threema edit begin ---------------------------
@property (nonatomic, weak) IBOutlet UITextField *textField;
@property (nonatomic, weak) IBOutlet UIImageView *threemaLogo;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *eraseDataButton;
@property (nonatomic, strong) UIButton *biometricButton;
@property (nonatomic, strong) UIButton *backspaceButton;
@property (nonatomic, strong) UIStackView *keypadStackView;
//------------------ Threema edit end ---------------------------
@property (strong, nonatomic) NSArray<JKLLockScreenNumber *> *numberButtons;

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
    [_eraseDataButton setTitle:KKPasscodeLockLocalizedString(@"Erase Data", @"") forState:UIControlStateNormal];
    //------------------ Threema edit end ---------------------------
    
    _passcodeLockOn = [[KKKeychain getStringForKey:@"passcode_on"] isEqualToString:@"YES"];
    _eraseData = [[KKPasscodeLock sharedLock] eraseOption] && [[KKKeychain getStringForKey:@"erase_data_on"] isEqualToString:@"YES"];
    
    _titleLabel.textColor = Colors.textLockScreen;
    _titleLabel.shadowColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.6];
    _subtitleLabel.textColor = Colors.textLockScreen;
    _subtitleLabel.shadowColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.6];
    [_eraseDataButton setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    [_eraseDataButton setTitleShadowColor:[UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.6] forState:UIControlStateNormal];
    [self.view setBackgroundColor:UIColor.blackColor];
    
    //------------------ Threema edit begin ---------------------------
    _threemaLogo.image = [Colors threemaLogoForPasscode];
    _threemaLogo.layer.cornerRadius = 10;
    //------------------ Threema edit end ---------------------------
        
    _pincodeView.pincodeColor = UIColor.primary;
    _tintColor = UIColor.primary;
    [self tintSubviewsWithColor:_tintColor];

    //------------------ Threema edit begin ---------------------------
    // Biometry can be switched on or off in Settings while the app is in the background
    [self lsv_refreshBiometricAvailability];
    //------------------ Threema edit end ---------------------------
}
//------------------ Threema edit end ---------------------------


- (void)viewDidLoad {
    [super viewDidLoad];
    //------------------ Threema edit begin ---------------------------
    
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    // Everything below the subtitle is built here, the nib only carries the logo, the labels and
    // the pincode dots
    [self lsv_setupKeypad];
    [self lsv_setupButtonsBelowKeypad];

    _cancelButton.titleLabel.adjustsFontSizeToFitWidth = YES;

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
    //------------------ Threema edit begin ---------------------------
    // `allowTouchIDLockScreenViewController:` is a data source selector, so ask the data source. A nil
    // data source opts out and leaves biometrics to the owner (see `PasscodeCoordinator`).
    if (isModeNormal && [_dataSource respondsToSelector:@selector(allowTouchIDLockScreenViewController:)]) {
    //------------------ Threema edit end ---------------------------
        if ([_dataSource allowTouchIDLockScreenViewController:self]) {
            // Touch ID 암호 입력창 호출
            [self lsv_policyDeviceOwnerAuthentication];
        }
    }
}

//------------------ Threema edit begin ---------------------------
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    // Owners such as `LockScreen` keep this controller around and present it again for the next unlock,
    // which is a new attempt that may offer biometrics again
    BOOL isDismissed = self.isBeingDismissed || self.navigationController.isBeingDismissed || self.isMovingFromParentViewController;
    if (isDismissed) {
        _biometricUnlockDisabled = NO;
    }
}
//------------------ Threema edit end ---------------------------

/**
 *  Changes buttons tint color
 *
 *  @param color tint color for buttons
 */
- (void)tintSubviewsWithColor: (UIColor *) color{
    [_cancelButton setTitleColor:color forState:UIControlStateNormal];
    //------------------ Threema edit begin ---------------------------
    // Carry no circle, so they follow the digits rather than the tint color drawn around them
    [_biometricButton setTintColor:Colors.textLockScreen];
    [_backspaceButton setTintColor:Colors.textLockScreen];
    //------------------ Threema edit end ---------------------------
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
    //------------------ Threema edit begin ---------------------------
    // The biometric button allows repeated tries, so don't stack evaluations
    if (_biometricAuthenticationInProgress || _biometricUnlockDisabled) {
        return;
    }
    //------------------ Threema edit end ---------------------------

    NSError   * error   = nil;
    LAContext * context = [[LAContext alloc] init];

    // check if the policy can be evaluated
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        //------------------ Threema edit begin ---------------------------
        _biometricAuthenticationInProgress = YES;

        NSString *reason = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"to_unlock_passcode"], TargetManagerObjC.appName];
        __weak typeof(self) weakSelf = self;
        //------------------ Threema edit end ---------------------------

        // evaluate
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason:reason
                          reply:^(BOOL success, NSError * authenticationError) {
                              //------------------ Threema edit begin ---------------------------
                              // The reply runs on a private queue, but everything below touches UI
                              dispatch_async(dispatch_get_main_queue(), ^{
                                  typeof(self) strongSelf = weakSelf;
                                  if (strongSelf == nil) {
                                      return;
                                  }

                                  strongSelf->_biometricAuthenticationInProgress = NO;

                                  if (success) {
                                      [strongSelf lsv_unlockDelayDismissViewController:LSVDismissWaitingDuration];
                                  }
                                  else {
                                      NSLog(@"LAContext::Authentication Error : %@", authenticationError);
                                      if ([TouchIDAuthentication requiresPasscodeAfterError:authenticationError]) {
                                          [strongSelf disableBiometricUnlock];
                                      }
                                  }
                              });
                              //------------------ Threema edit end ---------------------------
                          }];
    }
    else {
        NSLog(@"LAContext::Policy Error : %@", [error localizedDescription]);
    }

}

//------------------ Threema edit begin ---------------------------
#pragma mark -
#pragma mark Biometric unlock

/**
 Creates a digit key. `onNumberClicked:` reads the digit back off the tag.
 */
- (JKLLockScreenNumber *)lsv_makeDigitKey:(NSInteger)digit {
    JKLLockScreenNumber *key = [[JKLLockScreenNumber alloc] initWithFrame:CGRectZero];
    key.tag = digit;
    key.backgroundColor = UIColor.clearColor;
    key.opaque = NO;
    // The circle is drawn in drawRect:, so it has to be redrawn whenever the cell is resized
    key.contentMode = UIViewContentModeRedraw;
    [key setTitle:[@(digit) stringValue] forState:UIControlStateNormal];
    [key addTarget:self action:@selector(onNumberClicked:) forControlEvents:UIControlEventTouchUpInside];

    return key;
}

/**
 Creates one of the two keys that carry a symbol instead of a digit. They draw no circle.
 */
- (UIButton *)lsv_makeSymbolKeyWithAction:(SEL)action {
    UIButton *key = [UIButton buttonWithType:UIButtonTypeSystem];
    [key addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    return key;
}

/**
 Builds the keypad.

 The nib used to carry it, but there the twelve cells were sized by one chain of equality constraints
 hanging off a single width constraint on the 5. Any constraint that disturbed one cell collapsed the
 whole grid, and the nib reinstalls its size class variations after every attempt to correct that from
 code. Two nested stack views express the same grid without a constraint graph to fight.
 */
- (void)lsv_setupKeypad {
    if (_keypadStackView != nil) {
        return;
    }

    NSMutableArray<JKLLockScreenNumber *> *numbers = [NSMutableArray arrayWithCapacity:10];
    for (NSInteger digit = 0; digit <= 9; digit++) {
        [numbers addObject:[self lsv_makeDigitKey:digit]];
    }
    self.numberButtons = numbers;

    _biometricButton = [self lsv_makeSymbolKeyWithAction:@selector(onBiometricClicked:)];
    _biometricButton.alpha = 0.0;
    _biometricButton.userInteractionEnabled = NO;

    _backspaceButton = [self lsv_makeSymbolKeyWithAction:@selector(onDeleteClicked:)];
    _backspaceButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"delete"];

    NSArray<NSArray<UIView *> *> *rows = @[
        @[numbers[1], numbers[2], numbers[3]],
        @[numbers[4], numbers[5], numbers[6]],
        @[numbers[7], numbers[8], numbers[9]],
        @[_biometricButton, numbers[0], _backspaceButton]
    ];

    NSMutableArray<UIStackView *> *rowStacks = [NSMutableArray arrayWithCapacity:rows.count];
    for (NSArray<UIView *> *row in rows) {
        UIStackView *rowStack = [[UIStackView alloc] initWithArrangedSubviews:row];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.spacing = LSVKeypadColumnSpacing;
        [rowStacks addObject:rowStack];
    }

    UIStackView *keypad = [[UIStackView alloc] initWithArrangedSubviews:rowStacks];
    keypad.axis = UILayoutConstraintAxisVertical;
    keypad.distribution = UIStackViewDistributionFillEqually;
    keypad.spacing = LSVKeypadRowSpacing;
    keypad.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:keypad];
    _keypadStackView = keypad;

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;

    // Both stacks fill equally, so squaring one key squares all twelve
    NSLayoutConstraint *square = [
        numbers[1].heightAnchor constraintEqualToAnchor:numbers[1].widthAnchor
    ];

    // Yields to the width limit below, which is what shrinks the keys on a narrow or short screen
    NSLayoutConstraint *preferredWidth = [
        keypad.widthAnchor constraintEqualToConstant:3 * LSVKeypadKeySize + 2 * LSVKeypadColumnSpacing
    ];
    preferredWidth.priority = UILayoutPriorityRequired - 1;

    // Keeps the logo and the labels hugging the keypad instead of drifting to the top of the screen
    NSLayoutConstraint *hugSubtitle = [keypad.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor
                                                                       constant:LSVKeypadTopSpacing];
    hugSubtitle.priority = UILayoutPriorityDefaultHigh - 1;

    // Centering the keypad alone would leave all the slack below it, because the logo and the labels
    // hang off its top. Matching the space above the logo to the space under the keypad centers the
    // block as a whole, which is how the nib used to balance it.
    UILayoutGuide *spaceAboveLogo = [[UILayoutGuide alloc] init];
    UILayoutGuide *spaceBelowKeypad = [[UILayoutGuide alloc] init];
    [self.view addLayoutGuide:spaceAboveLogo];
    [self.view addLayoutGuide:spaceBelowKeypad];

    NSLayoutConstraint *balance = [spaceAboveLogo.heightAnchor
        constraintEqualToAnchor:spaceBelowKeypad.heightAnchor];
    balance.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [keypad.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [keypad.topAnchor constraintGreaterThanOrEqualToAnchor:_subtitleLabel.bottomAnchor
                                                      constant:LSVKeypadTopSpacing],
        [keypad.widthAnchor constraintLessThanOrEqualToAnchor:safeArea.widthAnchor
                                                     constant:-2 * LSVKeypadColumnSpacing],
        [spaceAboveLogo.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [spaceAboveLogo.bottomAnchor constraintEqualToAnchor:_threemaLogo.topAnchor],
        // The nib only keeps the logo 25pt off the top of the view, which on a notched screen is
        // above the safe area
        [spaceAboveLogo.heightAnchor constraintGreaterThanOrEqualToConstant:0],
        [spaceBelowKeypad.topAnchor constraintEqualToAnchor:keypad.bottomAnchor],
        [spaceBelowKeypad.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        square,
        preferredWidth,
        balance,
        hugSubtitle
    ]];
}

/**
 Places the cancel and the "Erase Data" button in the strip below the keypad. They are never shown in
 the same mode, so they share the position.
 */
- (void)lsv_setupButtonsBelowKeypad {
    if (_cancelButton != nil) {
        return;
    }

    _cancelButton = [self lsv_makeButtonBelowKeypadWithAction:@selector(onCancelClicked:)];
    _eraseDataButton = [self lsv_makeButtonBelowKeypadWithAction:@selector(onEraseDataClicked:)];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        [_cancelButton.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [safeArea.bottomAnchor constraintEqualToAnchor:_cancelButton.bottomAnchor constant:LSVBottomButtonInset],
        [_cancelButton.topAnchor constraintGreaterThanOrEqualToAnchor:_keypadStackView.bottomAnchor
                                                             constant:LSVBottomButtonSpacing],
        [_eraseDataButton.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [safeArea.bottomAnchor constraintEqualToAnchor:_eraseDataButton.bottomAnchor constant:LSVBottomButtonInset],
        [_eraseDataButton.topAnchor constraintGreaterThanOrEqualToAnchor:_keypadStackView.bottomAnchor
                                                                constant:LSVBottomButtonSpacing]
    ]];
}

- (UIButton *)lsv_makeButtonBelowKeypadWithAction:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [UIFont systemFontOfSize:17];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];

    return button;
}

/**
 Determines whether biometric unlock can be offered and updates the button for the enrolled biometry.
 */
- (void)lsv_refreshBiometricAvailability {
    _biometricUnlockAvailable = NO;
    _biometricSymbolName = nil;
    // Forces the symbols to be rebuilt, the enrolled biometry may have changed
    _keypadKeyHeight = 0;

    BOOL isModeNormal = (_lockScreenMode == LockScreenModeNormal || _lockScreenMode == LockScreenModeExtension);
    if (!isModeNormal || _biometricUnlockDisabled || ![[KKPasscodeLock sharedLock] isTouchIdOn]) {
        [self lsv_updateBiometricButtonVisibility];
        return;
    }

    NSError *error = nil;
    LAContext *context = [[LAContext alloc] init];

    // `biometryType` is only meaningful after evaluating this
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        NSLog(@"LAContext::Policy Error : %@", [error localizedDescription]);
        [self lsv_updateBiometricButtonVisibility];
        return;
    }

    NSString *accessibilityLabelKey = nil;

    switch (context.biometryType) {
        case LABiometryTypeFaceID:
            _biometricSymbolName = @"faceid";
            accessibilityLabelKey = @"passcode_unlock_with_face_id";
            break;
        case LABiometryTypeTouchID:
            _biometricSymbolName = @"touchid";
            accessibilityLabelKey = @"passcode_unlock_with_touch_id";
            break;
        default:
            // Optic ID and unknown future types are not supported for the passcode lock
            [self lsv_updateBiometricButtonVisibility];
            return;
    }

    _biometricButton.accessibilityLabel = [BundleUtil localizedStringForKey:accessibilityLabelKey];

    _biometricUnlockAvailable = YES;
    [self lsv_updateBiometricButtonVisibility];
    [self lsv_updateKeypadSymbols];
}

- (void)disableBiometricUnlock {
    _biometricUnlockDisabled = YES;
    _biometricUnlockAvailable = NO;
    [self lsv_updateBiometricButtonVisibility];
}

- (void)lsv_updateBiometricButtonVisibility {
    // Hiding an arranged subview collapses its cell: the row would fall back to two columns, the
    // remaining keys would stop lining up with the digits above them, and their cells would no
    // longer be square
    _biometricButton.alpha = _biometricUnlockAvailable ? 1.0 : 0.0;
    _biometricButton.userInteractionEnabled = _biometricUnlockAvailable;
}

/**
 Scales the symbols with the keypad, mirroring the ratio the digits have inside their cell.

 A single point size would not do: `delete.backward` is a wider and taller glyph than `faceid` at the
 same point size, so it gets its own ratio to carry the same visual weight as its neighbours.
 */
- (void)lsv_updateKeypadSymbols {
    CGFloat height = CGRectGetHeight(_backspaceButton.bounds);
    if (height <= 0) {
        return;
    }

    // Setting an image triggers another layout pass, so only redo the work on an actual size change
    if (fabs(height - _keypadKeyHeight) < 0.5) {
        return;
    }
    _keypadKeyHeight = height;

    UIFont *digitFont = [UIFont systemFontOfSize:round(height * LSVKeyDigitRatio) weight:UIFontWeightThin];
    for (JKLLockScreenNumber *number in _numberButtons) {
        number.titleLabel.font = digitFont;
    }

    [self lsv_setSymbolNamed:@"delete.backward"
                        font:[digitFont fontWithSize:round(height * LSVKeyBackspaceRatio)]
                       onKey:_backspaceButton];
    [self lsv_setSymbolNamed:_biometricSymbolName
                        font:[digitFont fontWithSize:round(height * LSVKeySymbolRatio)]
                       onKey:_biometricButton];
}

- (void)lsv_setSymbolNamed:(NSString *)symbolName font:(UIFont *)font onKey:(UIButton *)key {
    if (symbolName == nil || key == nil) {
        return;
    }

    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithFont:font];

    // Kept as a template so the tint color applies and the button dims it while highlighted
    [key setImage:[UIImage systemImageNamed:symbolName withConfiguration:configuration] forState:UIControlStateNormal];
}
//------------------ Threema edit end ---------------------------

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
            //------------------ Threema edit begin ---------------------------
            if ([_delegate respondsToSelector:@selector(didPasscodeViewDismiss:)]) {
                [_delegate performSelector:@selector(didPasscodeViewDismiss:) withObject:self];
            }
            //------------------ Threema edit end ---------------------------
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

- (IBAction)onBiometricClicked:(id)sender {
    if (_biometricUnlockDisabled) {
        return;
    }

    // The delegate may need to run its own flow, e.g. to detect a changed biometry enrollment
    if ([_delegate respondsToSelector:@selector(didRequestBiometricAuthentication:)]) {
        [_delegate didRequestBiometricAuthentication:self];
        return;
    }

    [self lsv_policyDeviceOwnerAuthentication];
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
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate {
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

//------------------ Threema edit begin ---------------------------
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self lsv_updateKeypadSymbols];
}
//------------------ Threema edit end ---------------------------

@end
