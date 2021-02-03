//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "SplashViewController.h"
#import "FLAnimatedImageView.h"
#import "FLAnimatedImage.h"
#import "BundleUtil.h"
#import "RectUtil.h"
#import <QuartzCore/QuartzCore.h>
#import "NibUtil.h"
#import "RandomSeedViewController.h"
#import "MyIdentityStore.h"
#import "IdentityBackupStore.h"
#import "ServerAPIConnector.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "ParallaxPageViewController.h"
#import "AppDelegate.h"
#import "UIDefines.h"
#import "UserSettings.h"
#import "NibUtil.h"

#import "ConfirmIDViewController.h"
#import "PickNicknameViewController.h"
#import "LinkIDViewController.h"
#import "SyncContactsViewController.h"
#import "CompletedIDViewController.h"
#import "RestoreIdentityViewController.h"

#import "IntroQuestionView.h"
#import "LicenseStore.h"
#import "EnterLicenseViewController.h"
#import "MDMSetup.h"
#import "ContactStore.h"
#import "Contact.h"
#import "GatewayAvatarMaker.h"
#import "Threema-Swift.h"
#import "ConversationUtils.h"
#import "WorkDataFetcher.h"
#import <StoreKit/StoreKit.h>

@interface SplashViewController () <FLAnimatedImageViewDelegate, RandomSeedViewControllerDelegate, CompletedIDDelegate, RestoreOptionDataViewControllerDelegate, RestoreOptionBackupViewControllerDelegate, RestoreSafeViewControllerDelegate, RestoreIdentityViewControllerDelegate, IntroQuestionDelegate, EnterLicenseDelegate, ZSWTappableLabelTapDelegate>

@property FLAnimatedImageView *animatedView;
@property RandomSeedViewController *randomSeedViewController;
@property RestoreOptionDataViewController *restoreOptionDataViewController;
@property RestoreOptionBackupViewController *restoreOptionBackupViewController;
@property RestoreSafeViewController *restoreSafeViewController;
@property RestoreIdentityViewController *restoreIdentityViewController;

@property IntroQuestionView *acceptPrivacyPolicyQuestionView;
@property IntroQuestionView *existingBackupQuestionView;
@property IntroQuestionView *existingIdQuestionView;

@property CGFloat parallaxDeltaX;
@property CGFloat bgImagescale;

@property NSString *idBackup;

@property BOOL triggeredSetup;
@property BOOL isRestoreOptionBackupDisplayed;

@property (assign) BOOL hasDataOnDevice;

@end

@implementation SplashViewController {
    MDMSetup *mdmSetup;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if ([MyIdentityStore sharedMyIdentityStore].pendingCreateID) {
        _bgImagescale = 1.5;
    } else {
        // during intro image will be zoomed
        _bgImagescale = 1.2;
    }

    [self setupControls];

    [self setupBackgroundView];

    [self setNeedsStatusBarAppearanceUpdate];

    [mdmSetup loadIDCreationValues];

    // Work logo
    if ([LicenseStore requiresLicenseKey]) {
        _threemaLogoView.image = [BundleUtil imageNamed:@"ThreemaWork"];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    _restoreButton.hidden = [mdmSetup disableBackups];
    _threemaLogoView.hidden = YES;
}

- (void)setupBackgroundView {
    CGFloat width = self.view.frame.size.width;
    CGFloat height = self.view.frame.size.height;

    _parallaxDeltaX = - width*_bgImagescale/20.0;

    CGRect bgRect = CGRectMake(0.0, 0.0, width*(_bgImagescale*2), height*_bgImagescale);
    bgRect = [RectUtil rect:bgRect centerIn:self.view.frame];
    // fix for iPad landscape
    _bgView.frame = CGRectMake(bgRect.origin.x, bgRect.origin.y, bgRect.size.width, bgRect.size.height);

    [self.view sendSubviewToBack:_bgView];
}

- (void)setupAnimatedView {
    if (_animatedView == nil) {
        CGFloat logoScale = 2.2;
        CGRect rect = CGRectMake(0, 0, 250.0/logoScale, 300.0/logoScale);
        rect = [RectUtil rect:rect centerIn:self.view.frame round:YES];

        _animatedView = [[FLAnimatedImageView alloc] initWithFrame:rect];
        
        NSString *animationName = nil;
        if ([LicenseStore requiresLicenseKey]) {
            animationName = @"logoAnimation_work";
        } else {
            animationName = @"logoAnimation";
        }
        NSURL *url = [BundleUtil URLForResource:animationName withExtension:@"gif"];
        FLAnimatedImage *image = [FLAnimatedImage animatedImageWithGIFData:[NSData dataWithContentsOfURL:url] ];
        _animatedView.animatedImage = image;
        _animatedView.delegate = self;
    }
}

- (void)setupControls {
    _setupButton.backgroundColor = [Colors mainThemeDark];
    
    _privacyView.hidden = YES;
    _privacyView.frame = [RectUtil rect:_privacyView.frame centerHorizontalIn:_containerView.frame];
    _controlsView.hidden = YES;
    _controlsView.frame = [RectUtil rect:_controlsView.frame centerHorizontalIn:_containerView.frame];
    _setupButton.layer.cornerRadius = 5;
    [_setupButton setTitleColor:[Colors white] forState:UIControlStateNormal];
    
    _restoreButton.layer.borderWidth = 1;
    _restoreButton.layer.borderColor = _setupButton.backgroundColor.CGColor;
    _restoreButton.layer.cornerRadius = 5;
    _restoreButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    _restoreButton.titleLabel.minimumScaleFactor = 0.6;
    [_restoreButton setTitleColor:[Colors mainThemeDark] forState:UIControlStateNormal];
    
    _privacyPolicySwitch.onTintColor = [Colors mainThemeDark];
    
    _welcomeLabel.text = [BundleUtil localizedStringForKey:@"lets_get_started"];
    NSString *privacyPolicyText;
    
    if ([LicenseStore requiresLicenseKey]) {
        [_setupButton setTitle:[BundleUtil localizedStringForKey:@"setup_threema_work"] forState:UIControlStateNormal];
        privacyPolicyText = [BundleUtil localizedStringForKey:@"privacy_policy_about_work"];
    } else {
        [_setupButton setTitle:[BundleUtil localizedStringForKey:@"setup_threema"] forState:UIControlStateNormal];
        privacyPolicyText = [BundleUtil localizedStringForKey:@"privacy_policy_about"];
    }
    [_restoreButton setTitle:[BundleUtil localizedStringForKey:@"restore_id"] forState:UIControlStateNormal];
    
    _privacyPolicyInfo.font = [UIFont systemFontOfSize:16.0];
    _privacyPolicyInfo.tapDelegate = self;
    NSDictionary *normalAttributes = @{NSFontAttributeName: _privacyPolicyInfo.font, NSForegroundColorAttributeName: [UIColor whiteColor]};
    NSDictionary *linkAttributes = @{@"ZSWTappableLabelTappableRegionAttributeName": @YES,
                                     @"ZSWTappableLabelHighlightedForegroundAttributeName": [Colors red],
                                     NSForegroundColorAttributeName: [Colors privacyPolicyLink],
                                     NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                                     @"NSTextCheckingResult": @1
                                     };
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:privacyPolicyText attributes:normalAttributes];
    CGRect infoRect = [attributedString boundingRectWithSize:CGSizeMake(_privacyView.frame.size.width, 400.0) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
    if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
        /* iPhone 4s */
        _welcomeLabel.frame = CGRectMake(_welcomeLabel.frame.origin.x, _welcomeLabel.frame.origin.y - 20.0, _welcomeLabel.frame.size.width, _welcomeLabel.frame.size.height);
        _privacyPolicyInfo.frame = CGRectMake(_privacyPolicyInfo.frame.origin.x, _privacyPolicyInfo.frame.origin.y - 50.0, infoRect.size.width, infoRect.size.height + 20.0);
    } else {
        _privacyPolicyInfo.frame = CGRectMake(_privacyPolicyInfo.frame.origin.x, _privacyPolicyInfo.frame.origin.y, infoRect.size.width, infoRect.size.height + 20.0);
    }
    [attributedString addAttributes:linkAttributes range:[privacyPolicyText rangeOfString:[BundleUtil localizedStringForKey:@"privacy_policy_about_link"]]];
    _privacyPolicyInfo.attributedText = attributedString;
    
    _privacyPolicyLabel.text = [BundleUtil localizedStringForKey:@"accept_privacy_policy"];
    _privacyPolicySwitch.accessibilityLabel = [BundleUtil localizedStringForKey:@"privacy_policy_switch"];
    
    CGRect labelRect = [_privacyPolicyLabel.text boundingRectWithSize:CGSizeMake(_privacyView.frame.size.width - _privacyPolicySwitch.frame.size.width - 15.0, 400.0) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:normalAttributes context:nil];
    _privacyPolicyLabel.frame = CGRectMake(_privacyPolicySwitch.frame.size.width + 15.0, _privacyPolicyInfo.frame.origin.y + _privacyPolicyInfo.frame.size.height + 15.0, labelRect.size.width, labelRect.size.height);
    
    if (_privacyPolicyLabel.frame.size.height > _privacyPolicySwitch.frame.size.height) {
        _privacyPolicySwitch.frame = CGRectMake(0.0, _privacyPolicyLabel.frame.origin.y + ((_privacyPolicyLabel.frame.size.height - _privacyPolicySwitch.frame.size.height) /2), _privacyPolicySwitch.frame.size.width, _privacyPolicySwitch.frame.size.height);
    } else {
        _privacyPolicySwitch.frame = CGRectMake(0.0, _privacyPolicyInfo.frame.origin.y + _privacyPolicyInfo.frame.size.height + 8.0, _privacyPolicySwitch.frame.size.width, _privacyPolicySwitch.frame.size.height);
    }
    
    AppSetupState *appSetupState = [[AppSetupState alloc] init];
    [self setHasDataOnDevice:[appSetupState existsDatabaseFile]];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return NO;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (@available(iOS 11.0, *)) {
        _threemaLogoView.frame = CGRectMake(_threemaLogoView.frame.origin.x, self.view.safeAreaLayoutGuide.layoutFrame.origin.y + 26.0, _threemaLogoView.frame.size.width, _threemaLogoView.frame.size.height);
    }

    [self presentUI];
}

- (void)presentUI {
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if ([[LicenseStore sharedLicenseStore] isValid] == NO) {
        [self performLicenseCheck];
    } else if ([mdmSetup isSafeRestoreForce]) {
        [self showRestoreSafeViewController:[self hasDataOnDevice]];
        [self slideOut:self fromRightToLeft:YES onCompletion:nil];
        [self slideIn:_restoreSafeViewController fromLeftToRight:YES  onCompletion:nil];
    } else if ([mdmSetup hasIDBackup] && appSetupState.isAppSetupCompleted == false) {
        [self restoreIDFromMDM];
    } else if ([MyIdentityStore sharedMyIdentityStore].pendingCreateID) {
        [self presentPageViewController];
    } else {
        _threemaLogoView.hidden = NO;
        
        [self setupAnimatedView];
        [self checkRefreshStoreReceipt];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (_animatedView.superview == nil) {
                [_containerView addSubview:_animatedView];
            }
        });
    }
}

- (void)slidePrivacyControlsIn {
    CGRect viewFrame;
    if (@available(iOS 11.0, *)) {
        viewFrame = self.view.safeAreaLayoutGuide.layoutFrame;
    } else {
        viewFrame = self.view.frame;
    }
    
    CGRect privacyTargetRect;
    
    if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
        /* iPhone 4s */
        privacyTargetRect = [RectUtil setYPositionOf:_privacyView.frame y:120.0];
    } else {
        privacyTargetRect = [RectUtil setYPositionOf:_privacyView.frame y:170.0];
    }
    
    CGRect animationTargetRect = [RectUtil setYPositionOf:_animatedView.frame y:privacyTargetRect.origin.y - _animatedView.frame.size.height];

    CGRect privacySourceRect = [RectUtil setYPositionOf:_privacyView.frame y:_privacyView.frame.origin.y];

    CGRect controlsTargetRect;
    if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
        /* iPhone 4s */
        controlsTargetRect = [RectUtil setYPositionOf:_controlsView.frame y:privacyTargetRect.origin.y + privacyTargetRect.size.height - 40.0];
    } else {
        controlsTargetRect = [RectUtil setYPositionOf:_controlsView.frame y:privacyTargetRect.origin.y + privacyTargetRect.size.height];
    }
    
    CGRect controlsSourceRect = [RectUtil setYPositionOf:_controlsView.frame y:viewFrame.size.height];

    _privacyView.hidden = NO;
    _privacyView.alpha = 0.0;
    _privacyView.frame = privacySourceRect;
    _controlsView.hidden = NO;
    _controlsView.alpha = 0.0;
    _controlsView.frame = controlsSourceRect;

    [UIView animateWithDuration:1.2 delay:0.0 usingSpringWithDamping:0.9 initialSpringVelocity:10.0 options:0 animations:^{
        _privacyView.alpha = 1.0;
        _privacyView.frame = privacyTargetRect;
        _animatedView.frame = animationTargetRect;
        _controlsView.alpha = 1.0;
        _controlsView.frame = controlsTargetRect;
    } completion:^(BOOL finished) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.welcomeLabel);
        ;//nop
    }];
}

- (void)restoreIDFromMDM {
    [self setAcceptPrivacyPolicyValues:AcceptPrivacyPolicyVariantImplicitly];
    [mdmSetup restoreIDBackupOnCompletion:^{
        [self presentPageViewController];
    } onError:^(NSError *error) {
        _restoreIdentityViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RestoreIdentityViewController"];
        _restoreIdentityViewController.delegate = self;
        _restoreIdentityViewController.backupData = mdmSetup.idBackup;
        _restoreIdentityViewController.passwordData = mdmSetup.idBackupPassword;
        [_restoreIdentityViewController setup];

        [self slideOut:self fromRightToLeft:YES onCompletion:nil];
        [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:^{
            // make sure controls are visible
            _privacyView.alpha = 1.0;
            _privacyView.hidden = NO;
            _privacyView.frame = [RectUtil rect:_privacyView.frame centerIn:self.view.frame];

            // show error message
            [_restoreIdentityViewController handleError:error];
        }];
    }];
}

- (void)performLicenseCheck {
    LicenseStore *licenseStore = [LicenseStore sharedLicenseStore];
    [licenseStore performLicenseCheckWithCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self presentUI];
            } else {
                // present anyway, to also fail early if there is no network connection
                [self presentLicenseViewController];
            }
        });
    }];
}

- (void)presentLicenseViewController {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"License" bundle:nil];

    EnterLicenseViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.delegate = self;
    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:viewController animated:NO completion:nil];
}

- (void)presentPageViewController {
    ConfirmIDViewController *confirmVc = [self.storyboard instantiateViewControllerWithIdentifier:@"ConfirmIDViewController"];
    SafeViewController *safeVc = [self.storyboard instantiateViewControllerWithIdentifier:@"SafeSetup"];
    PickNicknameViewController *pickNicknameVc = [self.storyboard instantiateViewControllerWithIdentifier:@"PickNicknameViewController"];
    LinkIDViewController *linkIdVc = [self.storyboard instantiateViewControllerWithIdentifier:@"LinkIDViewController"];
    SyncContactsViewController *syncVc = [self.storyboard instantiateViewControllerWithIdentifier:@"SyncContactsViewController"];
    CompletedIDViewController *complededVc = [self.storyboard instantiateViewControllerWithIdentifier:@"CompletedIDViewController"];
    complededVc.delegate = self;

    ParallaxPageViewController *pageVc = [self.storyboard instantiateViewControllerWithIdentifier:@"ParallaxPageViewController"];

    if ([mdmSetup skipWizard]) {
        pageVc.viewControllers = @[complededVc];
    } else {
        if ([mdmSetup isSafeBackupDisable] || ([mdmSetup isSafeBackupForce] && [mdmSetup isSafeBackupPasswordPreset])) {
            pageVc.viewControllers = @[confirmVc, pickNicknameVc, linkIdVc, syncVc, complededVc];
        } else {
            pageVc.viewControllers = @[confirmVc, safeVc, pickNicknameVc, linkIdVc, syncVc, complededVc];
        }
    }

    pageVc.bgView = _bgView;
    pageVc.parallaxFactor = [NSNumber numberWithDouble: fabs(_parallaxDeltaX/self.view.frame.size.width)];
    pageVc.modalPresentationStyle = UIModalPresentationFullScreen;
    
    // make sure to clean up
    [_randomSeedViewController willMoveToParentViewController:nil];
    [_restoreIdentityViewController willMoveToParentViewController:nil];
    [self presentViewController:pageVc animated:NO completion:^{
        [_randomSeedViewController.view removeFromSuperview];
        [_randomSeedViewController removeFromParentViewController];

        [_restoreIdentityViewController.view removeFromSuperview];
        [_restoreIdentityViewController removeFromParentViewController];
    }];
}

- (void)showApplicaitonUI {
    [[AppDelegate sharedAppDelegate] completedIDSetup];
}

#pragma mark - IntroQuestionView

- (void)showAlertAcceptPrivacyPolicy {
    if (_acceptPrivacyPolicyQuestionView == nil) {
        _acceptPrivacyPolicyQuestionView = (IntroQuestionView *)[NibUtil loadViewFromNibWithName:@"IntroQuestionView"];
        if ([LicenseStore requiresLicenseKey]) {
            _acceptPrivacyPolicyQuestionView.questionLabel.text = [BundleUtil localizedStringForKey:@"privacy_policy_alert_text_work"];
        } else {
            _acceptPrivacyPolicyQuestionView.questionLabel.text = [BundleUtil localizedStringForKey:@"privacy_policy_alert_text"];
        }

        _acceptPrivacyPolicyQuestionView.delegate = self;
        _acceptPrivacyPolicyQuestionView.showOnlyOkButton = YES;
        _acceptPrivacyPolicyQuestionView.frame = [RectUtil rect:_acceptPrivacyPolicyQuestionView.frame centerIn:self.view.frame round:YES];

        [self.view addSubview:_acceptPrivacyPolicyQuestionView];
    }

    [self showMessageView:_acceptPrivacyPolicyQuestionView];
}

- (void)hideAcceptPrivacyPolicyQuestion {
    [self hideMessageView:_acceptPrivacyPolicyQuestionView];
}

- (void)showIDBackupQuestion {
    
    if (_existingBackupQuestionView == nil) {
        _existingBackupQuestionView = (IntroQuestionView *)[NibUtil loadViewFromNibWithName:@"IntroQuestionView"];
        _existingBackupQuestionView.tag = 1;
        _existingBackupQuestionView.questionLabel.text = [BundleUtil localizedStringForKey:@"backup_found_message"];;
        _existingBackupQuestionView.delegate = self;
        _existingBackupQuestionView.frame = [RectUtil rect:_existingBackupQuestionView.frame centerIn:self.view.frame round:YES];
        
        [self.view addSubview:_existingBackupQuestionView];
    }
    
    [self showMessageView:_existingBackupQuestionView];
}

- (void)hideIDBackupQuestion {
    [self hideMessageView:_existingBackupQuestionView];
}

- (void)showIDExistsQuestion {
    
    if (_existingIdQuestionView == nil) {
        _existingIdQuestionView = (IntroQuestionView *)[NibUtil loadViewFromNibWithName:@"IntroQuestionView"];
        _existingIdQuestionView.tag = 2;
        _existingIdQuestionView.questionLabel.text = [[NSString alloc] initWithFormat:[BundleUtil localizedStringForKey:@"id_exists"], [[MyIdentityStore sharedMyIdentityStore] identity]];
        _existingIdQuestionView.delegate = self;
        _existingIdQuestionView.frame = [RectUtil rect:_existingIdQuestionView.frame centerIn:self.view.frame round:YES];
        
        [self.view addSubview:_existingIdQuestionView];
    }
    
    [self showMessageView:_existingIdQuestionView];
}

- (void)hideIDExistsQuestion {
    [self hideMessageView:_existingIdQuestionView];
}


#pragma mark - FLAnimatedImageViewDelegate

- (void)animatedImageViewWillDrawFrame:(NSUInteger)frameIndex {
    if ((int)frameIndex == 0 && _privacyView.hidden == NO) {
        // stay at last frame
        _animatedView.currentFrameIndex = 78;
    } else if ((int)frameIndex == 0) {
        CGFloat duration = 1.0;
        UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseInOut;
        [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
            _bgImagescale = 1.5;
            [self setupBackgroundView];
        } completion:nil];
    } else if ((int)frameIndex == 72  && _privacyView.hidden == YES) {
        [self slidePrivacyControlsIn];
    }
}

#pragma mark - manage views

- (void)showSetupViewController {
    _randomSeedViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RandomSeedViewController"];
    _randomSeedViewController.delegate = self;
    [_randomSeedViewController setup];

    [self setAcceptPrivacyPolicyValues:AcceptPrivacyPolicyVariantExplicitly];
}

- (void)showRestoreOptionDataViewController {
    _restoreOptionDataViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RestoreOptionDataViewController"];
    _restoreOptionDataViewController.delegate = self;

    [self setAcceptPrivacyPolicyValues:AcceptPrivacyPolicyVariantExplicitly];
}

- (void)showRestoreOptionBackupViewController {
    _restoreOptionBackupViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RestoreOptionBackupViewController"];
    _restoreOptionBackupViewController.delegate = self;
    _restoreOptionBackupViewController.hasDataOnDevice = [self hasDataOnDevice];

    [self setAcceptPrivacyPolicyValues:AcceptPrivacyPolicyVariantExplicitly];
}

- (void)showRestoreSafeViewController:(BOOL)doRestoreIdentityOnly {
    _restoreSafeViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RestoreSafeViewController"];
    _restoreSafeViewController.delegate = self;
    _restoreSafeViewController.restoreIdentityOnly = doRestoreIdentityOnly;
}

- (void)showRestoreIdentityViewController:(NSString *)backupData {
    _restoreIdentityViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RestoreIdentityViewController"];
    _restoreIdentityViewController.delegate = self;
    _restoreIdentityViewController.backupData = backupData;
}

- (void)showRestoreIdentityViewController {
    if (_privacyPolicySwitch.on) {
        _triggeredSetup = NO;

        _isRestoreOptionBackupDisplayed = ([self.childViewControllers count] > 0 && [self.childViewControllers[0] isKindOfClass:[RestoreOptionBackupViewController class]]) != 0 ? YES : NO;

        if (_isRestoreOptionBackupDisplayed) {
            [self showRestoreIdentityViewController:nil];
            [self slideOut:_restoreOptionBackupViewController fromRightToLeft:YES onCompletion:nil];
            [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:nil];
        } else if ([self.childViewControllers count] == 0) {
            [self showRestoreIdentityViewController:nil];
            [self slideOut:self fromRightToLeft:YES onCompletion:nil];
            [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:nil];
        }
    } else {
        [self showAlertAcceptPrivacyPolicy];
    }
}

- (void)slideIn:(UIViewController *)child fromLeftToRight:(BOOL)toRight onCompletion:(void(^)(void))onCompletion {
    UIView *childView;
    if ([child isKindOfClass:[SplashViewController class]]) {
        childView = _containerView;
    } else {
        [self addChildViewController:child];

        childView = child.view;
        [self.view addSubview:childView];
    }

    //start position
    if (toRight) {
        childView.frame = [RectUtil setXPositionOf:childView.frame x:self.view.frame.size.width];
    } else {
        childView.frame = [RectUtil setXPositionOf:childView.frame x:self.view.frame.size.width * -1.0];
    }

    [child beginAppearanceTransition:YES animated:YES];
    [UIView animateWithDuration:0.5 animations:^{
        //end position
        childView.frame = [RectUtil setXPositionOf:childView.frame x:0];

        CGFloat parallaxFactor = toRight == YES ? 1.0 : -1.0;
        _bgView.frame = [RectUtil offsetRect:_bgView.frame byX:_parallaxDeltaX*parallaxFactor byY:0.0];
    } completion:^(BOOL finished) {
        [child endAppearanceTransition];
        [child didMoveToParentViewController:self];

        if (onCompletion) {
            onCompletion();
        }
    }];
}

- (void)slideOut:(UIViewController *)child fromRightToLeft:(BOOL)toLeft onCompletion:(void(^)(void))onCompletion {
    UIView *childView;
    if ([child isKindOfClass:[SplashViewController class]]) {
        childView = _containerView;
    } else {
        childView = child.view;
    }

    //start position
    childView.frame = [RectUtil setXPositionOf:childView.frame x:0];

    [child beginAppearanceTransition:NO animated:YES];
    [UIView animateWithDuration:0.5 animations:^{
        //end position
        if (toLeft) {
            childView.frame = [RectUtil setXPositionOf:childView.frame x:self.view.frame.size.width * -1.0];
        } else {
            childView.frame = [RectUtil setXPositionOf:childView.frame x:self.view.frame.size.width];
        }
    } completion:^(BOOL finished) {
        [child endAppearanceTransition];
        if (![child isKindOfClass:[SplashViewController class]]) {
            [childView removeFromSuperview];
            [child removeFromParentViewController];
        }

        if (onCompletion) {
            onCompletion();
        }
    }];
}

- (void)createIdentity {    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];

    [[[ServerAPIConnector alloc] init] createIdentityWithStore:[MyIdentityStore sharedMyIdentityStore] onCompletion:^(MyIdentityStore *store) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];

        store.pendingCreateID = YES;
        [self presentPageViewController];
    } onError:^(NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:error.localizedDescription message:error.localizedFailureReason preferredStyle:UIAlertControllerStyleAlert];
        [errAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"try_again", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self createIdentity];
        }]];
        [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:errAlert animated:YES completion:nil];
    }];
}


- (void)setAcceptPrivacyPolicyValues:(int)variant {
    [[UserSettings sharedUserSettings] setAcceptedPrivacyPolicyDate:[NSDate date]];
    [[UserSettings sharedUserSettings] setAcceptedPrivacyPolicyVariant:variant];
}

#pragma mark - private

- (NSString *)getIDBackup {
    NSString *backupData = [IdentityBackupStore loadIdentityBackup];
    if (backupData != nil && [[MyIdentityStore sharedMyIdentityStore] isValidBackupFormat:backupData]) {
        return backupData;
    }

    return nil;
}

- (BOOL)checkForIDBackup {
    _idBackup = [self getIDBackup];

    if (_idBackup) {
        [self showIDBackupQuestion];
        return YES;
    }

    return NO;
}

- (BOOL)checkForIDExists {
    if ([[MyIdentityStore sharedMyIdentityStore] isProvisioned]) {
        [self showIDExistsQuestion];
        return YES;
    }
    return NO;
}

- (void)addEchoEchoToContacts {
    [[ContactStore sharedContactStore] addContactWithIdentity:@"ECHOECHO" verificationLevel:kVerificationLevelUnverified onCompletion:^(Contact *contact, BOOL alreadyExists) {
        if (contact.isGatewayId) {
            [[GatewayAvatarMaker gatewayAvatarMaker] loadAndSaveAvatarForId:contact.identity];
        }
    } onError:^(NSError *error) {
        // do nothing
    }];
}

- (void)checkRefreshStoreReceipt {
    if ([LicenseStore requiresLicenseKey]) {
        return;
    }
    
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    if (receiptUrl && ![[NSFileManager defaultManager] fileExistsAtPath:receiptUrl.path]) {
        // No receipt available; try to refresh
        SKReceiptRefreshRequest *refreshRequest = [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:nil];
        [refreshRequest start];        
    }
}

#pragma mark - IBActions

- (IBAction)setupAction:(id)sender {
    if (_privacyPolicySwitch.on) {
        _triggeredSetup = YES;
        // Check for ID Export, if Threema Work or if Threema and has no existing ID
        if ([LicenseStore requiresLicenseKey] || (![LicenseStore requiresLicenseKey] && ![self checkForIDExists])) {
            if ([self checkForIDBackup] == NO) {
                [self showSetupViewController];
                [self slideOut:self fromRightToLeft:YES onCompletion:nil];
                [self slideIn:_randomSeedViewController fromLeftToRight:YES onCompletion:nil];
            }
        }
    } else {
        [self showAlertAcceptPrivacyPolicy];
    }
}

- (IBAction)restoreAction:(id)sender {
    if (_privacyPolicySwitch.on) {
        _triggeredSetup = NO;

        if ([mdmSetup isSafeRestoreDisable]) {
            if ([self checkForIDBackup] == NO) {
                [self showRestoreIdentityViewController:nil];
                [self slideOut:self fromRightToLeft:YES onCompletion:nil];
                [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:nil];
            }
        } else {
            if ([self hasDataOnDevice] == YES) {
                [self showRestoreOptionDataViewController];
                [self slideOut:self fromRightToLeft:YES onCompletion:nil];
                [self slideIn:_restoreOptionDataViewController fromLeftToRight:YES onCompletion:nil];
            } else {
                [self showRestoreOptionBackupViewController];
                [self slideOut:self fromRightToLeft:YES onCompletion:nil];
                [self slideIn:_restoreOptionBackupViewController fromLeftToRight:YES onCompletion:nil];
            }
        }
    } else {
        [self showAlertAcceptPrivacyPolicy];
    }
}


#pragma mark - IntroQuestionViewDelegate

- (void)selectedYes:(IntroQuestionView *)sender {
    if (sender.tag == 1) {
        [self hideIDBackupQuestion];

        [self showRestoreIdentityViewController:_idBackup];
        [self slideOut:self fromRightToLeft:YES onCompletion:nil];
        [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:nil];
    }
    else if (sender.tag == 2) {
        [self hideIDExistsQuestion];
        [self presentPageViewController];
    }
}

- (void)selectedNo:(IntroQuestionView *)sender {
    if (sender.tag == 1) {
        [self hideIDBackupQuestion];

        if (_triggeredSetup) {
            [self showSetupViewController];
            [self slideOut:self fromRightToLeft:YES onCompletion:nil];
            [self slideIn:_randomSeedViewController fromLeftToRight:YES onCompletion:nil];
        } else {
            [self showRestoreIdentityViewController:nil];
            [self slideOut:self fromRightToLeft:YES onCompletion:nil];
            [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:nil];
        }
    }
    else if (sender.tag == 2) {
        [self hideIDExistsQuestion];
        
        [self showSetupViewController];
        [self slideOut:self fromRightToLeft:YES onCompletion:nil];
        [self slideIn:_randomSeedViewController fromLeftToRight:YES onCompletion:nil];
    }
}

- (void)selectedOk:(IntroQuestionView *)sender {
    [self hideAcceptPrivacyPolicyQuestion];
}


#pragma mark - RandomSeedViewControllerDelegate

- (void)generatedRandomSeed:(NSData *)seed {
    [[MyIdentityStore sharedMyIdentityStore] generateKeyPairWithSeed:seed];

    [self createIdentity];
}

#pragma mark - CompletedIDDelegate

- (void)completedIDSetup {
    if ([[DatabaseManager dbManager] shouldUpdateProtection]) {
        MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
        [myIdentityStore updateConnectionRights];
        [[DatabaseManager dbManager] updateProtection];
    }
    
    // Delete decrypted backup data from application documents folder
    [FileUtility  deleteAt: [[DocumentManager applicationDocumentsDirectory] URLByAppendingPathComponent:@"safe-backup.json"]];

    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    [appSetupState appSetupCompleted];
    
    [[ContactStore sharedContactStore] updateAllContactsToCNContact];
    [[ContactStore sharedContactStore] updateAllContacts];
    
    [ConversationUtils resetUnreadMessageCount];
    
    [NotificationManager generatePushSettingForAllGroups];

    [self addEchoEchoToContacts];
    [self showApplicaitonUI];
}

#pragma mark - RestoreOptionDataViewControllerDelegate

- (void)optionDataKeepLocal {
    _restoreOptionDataViewController.delegate = nil;
    [self showRestoreOptionBackupViewController];
    [self slideOut:_restoreOptionDataViewController fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_restoreOptionBackupViewController fromLeftToRight:YES onCompletion:nil];
}

- (void)optionDataCancelled {
    _restoreOptionDataViewController.delegate = nil;
    [self slideOut:_restoreOptionDataViewController fromRightToLeft:NO onCompletion:nil];
    [self slideIn:self fromLeftToRight:NO onCompletion:nil];
}

#pragma mark - RestoreOptionBackupViewControllerDelegate

- (void)restoreSafe {
    _restoreOptionBackupViewController.delegate = nil;
    [self showRestoreSafeViewController:NO];
    [self slideOut:_restoreOptionBackupViewController fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_restoreSafeViewController fromLeftToRight:YES  onCompletion:nil];
}

- (void)restoreIdentityFromSafe {
    _restoreOptionBackupViewController.delegate = nil;
    [self showRestoreSafeViewController:YES];
    [self slideOut:_restoreOptionBackupViewController fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_restoreSafeViewController fromLeftToRight:YES  onCompletion:nil];
}

- (void)restoreIdentity {
    _restoreOptionBackupViewController.delegate = nil;
    [self slideOut:_restoreOptionBackupViewController fromRightToLeft:YES onCompletion:nil];

    _isRestoreOptionBackupDisplayed = YES;

    if ([self checkForIDBackup] == NO) {
        [self showRestoreIdentityViewController:nil];
        [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:nil];
    }
}

- (void)restoreCancelled {
    _isRestoreOptionBackupDisplayed = NO;
    _restoreOptionBackupViewController.delegate = nil;
    [self slideOut:_restoreOptionBackupViewController fromRightToLeft:NO onCompletion:nil];

    if ([self hasDataOnDevice]) {
        [self showRestoreOptionDataViewController];
        [self slideIn:_restoreOptionDataViewController fromLeftToRight:NO onCompletion:nil];
    } else {
        [self slideIn:self fromLeftToRight:NO  onCompletion:nil];
    }
}

#pragma mark - RestoreSafeViewControllerDelegate

- (void)restoreSafeCancelled {
    _restoreSafeViewController.delegate = nil;
    [self showRestoreOptionBackupViewController];
    [self slideOut:_restoreSafeViewController fromRightToLeft:NO onCompletion:nil];
    [self slideIn:_restoreOptionBackupViewController fromLeftToRight:NO onCompletion:nil];
}

- (void)restoreSafeDone {
    _restoreSafeViewController.delegate = nil;
    
    [self completedIDSetup];
}

#pragma mark - RestoreIdentityViewControllerDelegate

- (void)restoreIdentityCancelled {
    _restoreIdentityViewController.delegate = nil;
    [self slideOut:_restoreIdentityViewController fromRightToLeft:NO onCompletion:nil];

    if (!_triggeredSetup && _isRestoreOptionBackupDisplayed) {
        [self showRestoreOptionBackupViewController];
        [self slideIn:_restoreOptionBackupViewController fromLeftToRight:NO onCompletion:nil];
    } else if (!_isRestoreOptionBackupDisplayed) {
        [self slideIn:self fromLeftToRight:NO onCompletion:nil];
    }
}

- (void)restoreIdentityDone {
    _restoreIdentityViewController.delegate = nil;
    [MyIdentityStore sharedMyIdentityStore].pendingCreateID = YES;
    [self presentPageViewController];
}

#pragma mark - EnterLicenseDelegate

- (void)licenseConfirmed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ZSWTappableLabel delegate

- (void)tappableLabel:(ZSWTappableLabel *)tappableLabel tappedAtIndex:(NSInteger)idx withAttributes:(NSDictionary *)attributes {
    UIStoryboard *storyboard = [AppDelegate getSettingsStoryboard];
    UIViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"PrivacyPolicyViewController"];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nc animated:YES completion:nil];
}

@end
