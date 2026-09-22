#import "SplashViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "RandomSeedViewController.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "UIDefines.h"
#import "ConfirmIDViewController.h"
#import "PickNicknameViewController.h"
#import "LinkIDViewController.h"
#import "SyncContactsViewController.h"
#import "CompletedIDViewController.h"
#import "RestoreIdentityViewController.h"
#import "IntroQuestionView.h"
#import "EnterLicenseViewController.h"
#import <StoreKit/StoreKit.h>
#import "OnboardingPageViewController.h"
#import "Threema-Swift.h"

@import FileUtility;
@import RemoteSecret;
@import Keychain;

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

@interface SplashViewController () <RandomSeedViewControllerDelegate, CompletedIDDelegate, RestoreOptionDataViewControllerDelegate, RestoreOptionBackupViewControllerDelegate, RestoreSafeViewControllerDelegate, RestoreIdentityViewControllerDelegate, IntroQuestionDelegate, EnterLicenseDelegate, ZSWTappableLabelTapDelegate, MFMailComposeViewControllerDelegate>

@property RandomSeedViewController *randomSeedViewController;
@property RestoreOptionDataViewController *restoreOptionDataViewController;
@property RestoreOptionBackupViewController *restoreOptionBackupViewController;
@property RestoreSafeViewController *restoreSafeViewController;
@property RestoreIdentityViewController *restoreIdentityViewController;
@property (weak) CompletedIDViewController *completedIDViewController;

@property IntroQuestionView *acceptPrivacyPolicyQuestionView;
@property IntroQuestionView *existingBackupQuestionView;
@property IntroQuestionView *existingIdQuestionView;

@property BOOL isRestoreOptionBackupDisplayed;

@property (assign) BOOL hasDataOnDevice;

@end

@implementation SplashViewController {
    MDMSetup *mdmSetup;
    BOOL shouldSkipSetup;
    UINavigationController *privacyPolicyNavigationController;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        mdmSetup = [MDMSetup new];
        shouldSkipSetup = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    [self setupControls];

    [self setNeedsStatusBarAppearanceUpdate];

    [mdmSetup loadIDCreationValues];
    [mdmSetup loadRenewableValues];

    _threemaLogoView.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _threemaLogoView.image = [Colors threemaLogo];
}

- (void)setupControls {
    
    _privacyView.hidden = YES;
    _privacyView.frame = [self rect:_privacyView.frame centerHorizontalIn:_containerView.frame round:NO];
    _controlsView.hidden = YES;
    _controlsView.frame = [self rect:_controlsView.frame centerHorizontalIn:_containerView.frame round:NO];
    
    _setupButton.backgroundColor = UIColor.tintColor;
    _setupButton.layer.cornerRadius = 5;
    _setupButton.accessibilityIdentifier = @"SplashViewControllerSetupButton";
    [_setupButton setTitleColor:Colors.textProminentButtonWizard forState:UIControlStateNormal];
   
    // We disable the button if remote secret is enabled and there is existing date, to force a restore
    if ([DatabaseManager isExistingDBEncrypted]) {
        _setupButton.enabled = NO;
        _setupButton.alpha = 0.5;
    }
    
    _restoreButton.backgroundColor = UIColor.tintColor;
    _restoreButton.layer.borderWidth = 1;
    _restoreButton.layer.borderColor = _setupButton.backgroundColor.CGColor;
    _restoreButton.layer.cornerRadius = 5;
    _restoreButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    _restoreButton.titleLabel.minimumScaleFactor = 0.6;
    _restoreButton.accessibilityIdentifier = @"SplashViewControllerRestoreButton";
    [_restoreButton setTitleColor:Colors.textProminentButtonWizard forState:UIControlStateNormal];
    
    _setupTitleLabel.textColor = Colors.textSetup;
    _setupTitleLabel.accessibilityElementsHidden = true;
    
    _restoreTitleLabel.textColor = Colors.textSetup;
    _restoreTitleLabel.accessibilityElementsHidden = true;
    
    _welcomeLabel.text = [BundleUtil localizedStringForKey:@"lets_get_started"];
    
    _restoreTitleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"restore_title_text"], TargetManagerObjC.appName];
    _setupTitleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"setup_title_text"], TargetManagerObjC.appName];
    
    [_setupButton setTitle:[BundleUtil localizedStringForKey:@"setup_threema"] forState:UIControlStateNormal];
    [_restoreButton setTitle:[BundleUtil localizedStringForKey:@"restore_backup_sentence"] forState:UIControlStateNormal];
    
    if (TargetManagerObjC.isOnPrem) {
        _privacyPolicyInfo.hidden = true;
    }
    else {
        NSString *privacyPolicyText = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"privacy_policy_about"], TargetManagerObjC.appName];
        
        _privacyPolicyInfo.font = [UIFont systemFontOfSize:16.0];
        _privacyPolicyInfo.tapDelegate = self;
        NSDictionary *normalAttributes = @{NSFontAttributeName: _privacyPolicyInfo.font, NSForegroundColorAttributeName: [UIColor whiteColor]};
        NSDictionary *linkAttributes = @{@"ZSWTappableLabelTappableRegionAttributeName": @YES,
                                         @"ZSWTappableLabelHighlightedForegroundAttributeName": UIColor.whiteColor,
                                         NSForegroundColorAttributeName: Colors.textWizardLink,
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
        _privacyPolicyInfo.isAccessibilityElement = YES;
    }
    
    [self setHasDataOnDevice:[AppSetup hasPreexistingDatabaseFile]];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return NO;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        CGRect privacyTargetRect;
        
        if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
            /* iPhone 4s */
            privacyTargetRect = CGRectMake(_privacyView.frame.origin.x, 120.0, _privacyView.frame.size.width, _privacyView.frame.size.height);
        } else {
            privacyTargetRect = CGRectMake(_privacyView.frame.origin.x, 170.0, _privacyView.frame.size.width, _privacyView.frame.size.height);
        }
                
        CGRect controlsTargetRect;
        if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
            /* iPhone 4s */
            privacyTargetRect = CGRectMake(_controlsView.frame.origin.x, privacyTargetRect.origin.y + privacyTargetRect.size.height - 40.0, _controlsView.frame.size.width, _controlsView.frame.size.height);
        } else {
            privacyTargetRect = CGRectMake(_controlsView.frame.origin.x, privacyTargetRect.origin.y + privacyTargetRect.size.height, _controlsView.frame.size.width, _controlsView.frame.size.height);
        }
                
        _privacyView.frame = privacyTargetRect;
        _controlsView.frame = controlsTargetRect;
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    _threemaLogoView.frame = CGRectMake((self.view.safeAreaLayoutGuide.layoutFrame.size.width - _threemaLogoView.frame.size.width)/2, self.view.safeAreaLayoutGuide.layoutFrame.origin.y + 26.0, _threemaLogoView.frame.size.width, _threemaLogoView.frame.size.height);
    
    [self.delegate splashViewControllerDidAppear:self];
}

- (void)setRestoreButtonHidden:(BOOL)hidden {
    _restoreButton.hidden = hidden;
}

- (void)showPrivacyControls {
    [self checkRefreshStoreReceipt];

    CGRect privacyTargetRect;
    
    if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
        /* iPhone 4s */
        privacyTargetRect = CGRectMake(_privacyView.frame.origin.x, 120.0, _privacyView.frame.size.width, _privacyView.frame.size.height);
    } else {
        privacyTargetRect = CGRectMake(_privacyView.frame.origin.x, 170.0, _privacyView.frame.size.width, _privacyView.frame.size.height);
    }
    
    CGRect controlsTargetRect;
    if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
        /* iPhone 4s */
        controlsTargetRect = CGRectMake(_controlsView.frame.origin.x, privacyTargetRect.origin.y + privacyTargetRect.size.height - 40.0, _controlsView.frame.size.width, _controlsView.frame.size.height);
    } else {
        controlsTargetRect = CGRectMake(_controlsView.frame.origin.x, privacyTargetRect.origin.y + privacyTargetRect.size.height, _controlsView.frame.size.width, _controlsView.frame.size.height);
    }
    
    _privacyView.hidden = NO;
    _controlsView.hidden = NO;
    
    _privacyView.alpha = 1.0;
    _privacyView.frame = privacyTargetRect;
    _controlsView.alpha = 1.0;
    _controlsView.frame = controlsTargetRect;
    
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.welcomeLabel);
    
    // Deactivate Multi Device if is enabled
    if ([[UserSettings sharedUserSettings] enableMultiDevice] == YES) {
        [[ServerConnector sharedServerConnector] deactivateMultiDevice];
        
        NSString *title = [BundleUtil localizedStringForKey:@"multi_device_linked_id_missing_title"];
        NSString *message =[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"multi_device_linked_id_missing_message"], TargetManagerObjC.appName];
        NSString *linkButton = [BundleUtil localizedStringForKey:@"multi_device_linked_id_missing_reset_button"];
        [UIAlertTemplate showOKAlertWithOwner:self title:title message:message titleOk:linkButton actionOk:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[ThreemaURLProviderObjC getURL:ThreemaURLProviderTypeMultiDeviceReset] options:@{} completionHandler:nil];
        }];
    }
}

- (void)showWorkDataFetchFailedAlert {
    NSString *title = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"work_data_fetch_failed_title"], TargetManagerObjC.appName];
    NSString *message = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"work_data_fetch_failed_message"], TargetManagerObjC.appName];
    [UIAlertTemplate showOKAlertWithOwner:self title:title message:message actionOk:^(UIAlertAction *action __unused)  {
        exit(0);
    }];
}

- (void)showLicenseViewController {
    BOOL showInfoView = false;
    LicenseStore *licenseStore = [LicenseStore sharedLicenseStore];
    // In Custom OnPrem Apps, the Threema Private info view is not displayed. Additionally, the view is not shown when one of the fields (username, password, or URL) is already set.    
    if (licenseStore.licenseUsername == nil && licenseStore.licensePassword == nil && licenseStore.onPremConfigUrl == nil && !TargetManagerObjC.isCustomOnPrem) {
        showInfoView = true;
    }
    
    EnterLicenseViewController *viewController = [EnterLicenseViewController instantiate];
    viewController.delegate = self;
    viewController.doWorkApiFetch = NO;
    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    viewController.view.hidden = true;
    
    FlavorInfoViewController *fc = [FlavorInfoViewController new];
    
    if (showInfoView) {
        UIViewController *flavorInfoViewController = [fc viewControllerWithDismiss:^{
            [viewController dismissViewControllerAnimated:YES completion:nil];
        }];
        flavorInfoViewController.modalPresentationStyle = UIModalPresentationFullScreen;
        
        [self presentViewController:viewController animated:NO completion:^{
            [viewController presentViewController:flavorInfoViewController animated:NO completion:^{
                viewController.view.hidden = false;
            }];
        }];
    }
    else {
        [self presentViewController:viewController animated:NO completion:^{
            viewController.view.hidden = false;
        }];
    }
}

- (void)presentPageViewControllerWithSetupConfiguration:(SetupConfiguration *_Nonnull)setupConfiguration {
    CompletedIDViewController *completedVc = [self.storyboard instantiateViewControllerWithIdentifier:@"CompletedIDViewController"];
    completedVc.delegate = self;
    completedVc.setupConfiguration = setupConfiguration;
    _completedIDViewController = completedVc;

    OnboardingPageViewController *pageVc = [self.storyboard instantiateViewControllerWithIdentifier:@"OnboardingPageViewController"];

    if ([mdmSetup skipWizard] || shouldSkipSetup == YES) {
        pageVc.viewControllers = @[completedVc];
    } else {
        ConfirmIDViewController *confirmVc = [self.storyboard instantiateViewControllerWithIdentifier:@"ConfirmIDViewController"];
        
        PickNicknameViewController *pickNicknameVc = [self.storyboard instantiateViewControllerWithIdentifier:@"PickNicknameViewController"];
        pickNicknameVc.setupConfiguration = setupConfiguration;
        
        LinkIDViewController *linkIdVc = [self.storyboard instantiateViewControllerWithIdentifier:@"LinkIDViewController"];
        linkIdVc.setupConfiguration = setupConfiguration;
        
        SyncContactsViewController *syncVc = [self.storyboard instantiateViewControllerWithIdentifier:@"SyncContactsViewController"];
        syncVc.setupConfiguration = setupConfiguration;
        
        if ([mdmSetup isSafeBackupDisable] || ([mdmSetup isSafeBackupForce] && [mdmSetup isSafeBackupPasswordPreset])) {
            pageVc.viewControllers = @[confirmVc, pickNicknameVc, linkIdVc, syncVc, completedVc];
        } else {
            SafeViewController *safeVc = [self.storyboard instantiateViewControllerWithIdentifier:@"SafeSetup"];
            safeVc.setupConfiguration = setupConfiguration;
            
            pageVc.viewControllers = @[confirmVc, safeVc, pickNicknameVc, linkIdVc, syncVc, completedVc];
        }
    }

    pageVc.modalPresentationStyle = UIModalPresentationFullScreen;
    
    // make sure to clean up
    [_randomSeedViewController willMoveToParentViewController:nil];
    [_restoreIdentityViewController willMoveToParentViewController:nil];
    [self presentViewController:pageVc animated:NO completion:^{
        [_randomSeedViewController.view removeFromSuperview];
        [_randomSeedViewController removeFromParentViewController];

        [_restoreIdentityViewController.view removeFromSuperview];
        [_restoreIdentityViewController removeFromParentViewController];
        
        if (shouldSkipSetup == NO || pageVc == nil) {
            return;
        }
            
        CompletedIDViewController *completedViewController =
            pageVc.viewControllers.lastObject;
        
        if (completedViewController == nil) {
            return;
        }
        
        [completedViewController
            finishAction:completedViewController.finishButton];
    }];
}

- (void)contactSupport:(NSString *)errorCode {
    MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
    mailController.mailComposeDelegate = self;
    
    if (TargetManagerObjC.isBusinessApp) {
        [mailController setToRecipients:@[@"support-work@threema.ch"]];
    }
    else {
        [mailController setToRecipients:@[@"support@threema.ch"]];
    }
        
    [mailController setSubject:[BundleUtil localizedStringForKey:@"contact_support_mail_subject"]];
    NSString *message = [NSString localizedStringWithFormat:[BundleUtil localizedStringForKey:@"contact_support_mail_message"], TargetManagerObjC.appName, TargetManagerObjC.localizedAppName, errorCode];
    [mailController setMessageBody:message isHTML:NO];
    
    [self presentViewController:mailController animated:YES completion:nil];
}

#pragma mark - IntroQuestionView

- (void)hideAcceptPrivacyPolicyQuestion {
    [self hideMessageView:_acceptPrivacyPolicyQuestionView];
}

- (void)showIDBackupQuestion {
    
    if (_existingBackupQuestionView == nil) {
        _existingBackupQuestionView = (IntroQuestionView *)[[(NSBundle *)[NSBundle mainBundle] loadNibNamed:@"IntroQuestionView" owner:nil options:nil] firstObject];
        _existingBackupQuestionView.tag = 1;
        _existingBackupQuestionView.questionLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"backup_found_message"], TargetManagerObjC.localizedAppName];
        _existingBackupQuestionView.delegate = self;
        _existingBackupQuestionView.frame = [self rect:_existingBackupQuestionView.frame centerIn:self.view.frame round:YES];
        
        [self.view addSubview:_existingBackupQuestionView];
    }
    
    [self showMessageView:_existingBackupQuestionView];
}

- (void)hideIDBackupQuestion {
    [self hideMessageView:_existingBackupQuestionView];
}

- (void)showIDExistsQuestionForIdentity:(nonnull NSString *)identity {
    
    if (_existingIdQuestionView == nil) {
        _existingIdQuestionView = (IntroQuestionView *)[[(NSBundle *)[NSBundle mainBundle] loadNibNamed:@"IntroQuestionView" owner:nil options:nil] firstObject];
        _existingIdQuestionView.tag = 2;
        _existingIdQuestionView.questionLabel.text = [NSString localizedStringWithFormat:[BundleUtil localizedStringForKey:@"id_exists"], TargetManagerObjC.localizedAppName, identity];
        _existingIdQuestionView.delegate = self;
        _existingIdQuestionView.frame = [self rect:_existingIdQuestionView.frame centerIn:self.view.frame round:YES];
        
        [self.view addSubview:_existingIdQuestionView];
    }
    
    [self showMessageView:_existingIdQuestionView];
}

- (void)hideIDExistsQuestion {
    [self hideMessageView:_existingIdQuestionView];
}

#pragma mark - manage views

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
}

- (void)slideOutRestoreOptionBackupViewController {
    [self slideOut:_restoreOptionBackupViewController fromRightToLeft:YES onCompletion:nil];
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
        childView.frame = CGRectMake(self.view.frame.size.width, childView.frame.origin.y, childView.frame.size.width, childView.frame.size.height);
    } else {
        childView.frame = CGRectMake(self.view.frame.size.width * -1.0, childView.frame.origin.y, childView.frame.size.width, childView.frame.size.height);
    }

    [child beginAppearanceTransition:YES animated:YES];
    [UIView animateWithDuration:0.5 animations:^{
        //end position
        childView.frame = CGRectMake(0, childView.frame.origin.y, childView.frame.size.width, childView.frame.size.height);
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
    childView.frame = CGRectMake(0, childView.frame.origin.y, childView.frame.size.width, childView.frame.size.height);

    [child beginAppearanceTransition:NO animated:YES];
    [UIView animateWithDuration:0.5 animations:^{
        //end position
        if (toLeft) {
            childView.frame = CGRectMake(self.view.frame.size.width * -1.0, childView.frame.origin.y, childView.frame.size.width, childView.frame.size.height);
        } else {
            childView.frame = CGRectMake(self.view.frame.size.width, childView.frame.origin.y, childView.frame.size.width, childView.frame.size.height);
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

- (void)setAcceptPrivacyPolicyValues:(int)variant {
    [[UserSettings sharedUserSettings] setAcceptedPrivacyPolicyDate:[NSDate date]];
    [[UserSettings sharedUserSettings] setAcceptedPrivacyPolicyVariant:variant];
}

#pragma mark - Private

- (void)checkRefreshStoreReceipt {
    if (TargetManagerObjC.isBusinessApp) {
        return;
    }
    
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    if (receiptUrl && ![[FileUtility new] fileExistsAt:receiptUrl]) {
        // No receipt available; try to refresh
        SKReceiptRefreshRequest *refreshRequest = [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:nil];
        [refreshRequest start];        
    }
}

#pragma mark - IBActions

- (IBAction)setupAction:(id)sender {
    __weak typeof(self) weakSelf = self;
    [self.delegate splashViewControllerDidTapSetup:self completionHandler:^{
        [weakSelf devSetup];
    }];
}

- (BOOL)isDevSetup {
#if DEBUG
    return YES;
#else
    return NO;
#endif
}

- (void)devSetup {
    if ([self isDevSetup] == NO) {
        return;
    }
    
    __weak typeof(RandomSeedViewController) *weakRandomSeedViewController = _randomSeedViewController;
    [UIAlertTemplate
        showAlertWithOwner:self
        title:@"Skip setup?"
        message:nil
        titleOk:@"Yes"
        actionOk:^(UIAlertAction *action __unused) {
            shouldSkipSetup = YES;
            [weakRandomSeedViewController.randomDataView
                generateRandomSeedWithNumberOfPositionsRequired:200];
        }
        titleCancel:@"No"
        actionCancel:nil
    ];
}

- (IBAction)restoreAction:(id)sender {
    [self.delegate splashViewControllerDidTapRestore:self];
}


#pragma mark - IntroQuestionViewDelegate

- (void)selectedYes:(IntroQuestionView *)sender {
    if (sender.tag == 1) {
        // ID Backup question - Yes = use backup
        [self hideIDBackupQuestion];
        [self.delegate splashViewController:self didAnswerIDBackupQuestion:YES];
    }
    else if (sender.tag == 2) {
        // ID Exists question - Yes = use existing
        [self hideIDExistsQuestion];
        [self.delegate splashViewController:self didAnswerIDExistsQuestion:YES];
    }
}

- (void)selectedNo:(IntroQuestionView *)sender {
    if (sender.tag == 1) {
        // ID Backup question - No = don't use backup
        [self hideIDBackupQuestion];
        [self.delegate splashViewController:self didAnswerIDBackupQuestion:NO];
    }
    else if (sender.tag == 2) {
        // ID Exists question - No = create new
        [self hideIDExistsQuestion];
        [self.delegate splashViewController:self didAnswerIDExistsQuestion:NO];
    }
}

- (void)selectedOk:(IntroQuestionView *)sender {
    [self hideAcceptPrivacyPolicyQuestion];
}


#pragma mark - RandomSeedViewControllerDelegate

- (void)generatedRandomSeed:(NSData *)seed {
    [self.delegate splashViewController:self didGenerateRandomSeed:seed];
}

#pragma mark - CompletedIDDelegate

- (void)completedIDSetupWithConfiguration:(SetupConfiguration *)setupConfiguration {
    [self.delegate splashViewController:self didCompleteIDSetupWith:setupConfiguration completionHandler:^(void){}];
}

- (void)cancelPressed {
    [self.delegate splashViewControllerDidCancelIDCreation:self];
}

- (void)cancelIDCreation {
    [self slideOut:_randomSeedViewController fromRightToLeft:NO onCompletion:nil];
    [self slideIn:self fromLeftToRight:NO onCompletion:nil];
}

#pragma mark - RestoreOptionDataViewControllerDelegate

- (void)optionDataKeepLocal {
    _restoreOptionDataViewController.delegate = nil;
    
    [self.delegate splashViewController:self didSelectRestoreOption:RestoreOptionKeepLocalData];
}

- (void)optionDataCancelled {
    _restoreOptionDataViewController.delegate = nil;
    
    [self.delegate splashViewControllerDidCancelRestore:self];
}

#pragma mark - RestoreOptionBackupViewControllerDelegate

- (void)restoreSafe {
    _restoreOptionBackupViewController.delegate = nil;
    
    [self.delegate splashViewController:self didSelectRestoreOption:RestoreOptionSafe];
}

- (void)restoreLocalBackup {
    [self.delegate splashViewController:self didSelectRestoreOption:RestoreOptionLocalBackup];
}

- (void)restoreIdentityFromSafe {
    _restoreOptionBackupViewController.delegate = nil;
    
    [self.delegate splashViewController:self didSelectRestoreOption:RestoreOptionSafeIdentityOnly];
}

- (void)restoreIdentity {
    _restoreOptionBackupViewController.delegate = nil;
    
    [self.delegate splashViewController:self didSelectRestoreOption:RestoreOptionIdBackup];
}

- (void)restoreCancelled {
    _restoreOptionBackupViewController.delegate = nil;
    
    [self.delegate splashViewControllerDidCancelRestoreOptionBackup:self];
}

#pragma mark - RestoreSafeViewControllerDelegate

- (void)restoreSafeCancelledWithShowLocalDataInfo:(BOOL)showLocalDataInfo {
    _restoreSafeViewController.delegate = nil;
    
    [self.delegate splashViewControllerDidCancelRestoreSafe:self];
}

- (void)restoreSafeViewController:(RestoreSafeViewController *)viewController
            didRequestRestoreWith:(NSString *)identity
                         password:(NSString *)password {
    [self.delegate splashViewController:self
                  didRequestSafeRestore:viewController
                               identity:identity
                               password:password];
}

#pragma mark - RestoreIdentityViewControllerDelegate

- (void)restoreIdentityCancelled {
    _restoreIdentityViewController.delegate = nil;
    
    [self.delegate splashViewControllerDidCancelRestoreIdentity:self];
}

- (void)restoreIdentityDone {
    _restoreIdentityViewController.delegate = nil;
    
    [self.delegate splashViewControllerDidCompleteRestoreIdentity:self];
}

#pragma mark - EnterLicenseDelegate

- (void)licenseConfirmed {
    [self dismissViewControllerAnimated:YES completion:nil];

    [self.delegate splashViewControllerDidConfirmLicense:self];
}

#pragma mark - ZSWTappableLabel delegate

- (void)tappableLabel:(ZSWTappableLabel *)tappableLabel tappedAtIndex:(NSInteger)idx withAttributes:(NSDictionary *)attributes {
    NSURL *url = [ThreemaURLProviderObjC getURL:ThreemaURLProviderTypePrivacyPolicy];
    NSString *title = [BundleUtil localizedStringForKey:@"settings_list_privacy_policy_title"];
    UIViewController *vc = [[SettingsWebViewViewController alloc] initWithUrl:url title:title allowsContentJavaScript:false isSetupWizard:true];
    privacyPolicyNavigationController = [[UINavigationController alloc] initWithRootViewController:vc];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed)];
    vc.navigationItem.rightBarButtonItem = doneButton;
    vc.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    vc.navigationController.navigationBar.translucent = true;
    vc.navigationController.navigationBar.tintColor = UIColor.tintColor;
    vc.navigationController.navigationBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    
    [self presentViewController:privacyPolicyNavigationController animated:YES completion:nil];
}

- (void)donePressed {
    [privacyPolicyNavigationController dismissViewControllerAnimated:true completion:nil];
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(nullable NSError *)error {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - New Public Methods for Coordinator

/// Returns the currently visible child view controller, or `self` if no child is displayed.
- (UIViewController *)currentVisibleViewController {
    if ([self.childViewControllers count] > 0) {
        return [self.childViewControllers lastObject];
    }
    return self;
}

- (void)showRandomSeedViewController {
    _randomSeedViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RandomSeedViewController"];
    _randomSeedViewController.delegate = self;
    [_randomSeedViewController setup];
    
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_randomSeedViewController fromLeftToRight:YES onCompletion:nil];
}

- (void)showRestoreIdentityViewControllerWithBackupData:(NSString *)backupData
                                               password:(NSString *)password
                                                  error:(NSError *)error {
    _restoreIdentityViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"RestoreIdentityViewController"];
    _restoreIdentityViewController.delegate = self;
    _restoreIdentityViewController.backupData = backupData;
    _restoreIdentityViewController.passwordData = password;
    [_restoreIdentityViewController setup];
    
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_restoreIdentityViewController fromLeftToRight:YES onCompletion:^{
        if (error != nil) {
            if (_privacyView.hidden) {
                // We can get here without the splash controls ever having been shown (MDM ID backup
                // restore). Make sure the privacy policy text is visible in that case.
                _privacyView.alpha = 1.0;
                _privacyView.hidden = NO;
                _privacyView.frame = [self rect:_privacyView.frame centerIn:self.view.frame round:NO];
            }

            [_restoreIdentityViewController handleError:error];
        }
    }];
}

- (void)navigateToRestoreOptionDataViewController {
    [self showRestoreOptionDataViewController];
    
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_restoreOptionDataViewController fromLeftToRight:YES onCompletion:nil];
}

- (void)navigateToRestoreOptionBackupViewController {
    [self showRestoreOptionBackupViewController];
    
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_restoreOptionBackupViewController fromLeftToRight:YES onCompletion:nil];
}

- (void)navigateToViewController:(UIViewController *)viewController {
    [self navigateToViewController:viewController fromRightToLeft:YES];
}

- (void)navigateBackToViewController:(UIViewController *)viewController {
    [self navigateToViewController:viewController fromRightToLeft:NO];
}

- (void)navigateToViewController:(UIViewController *)viewController fromRightToLeft:(BOOL)toLeft {
    // `slideIn:` only animates the horizontal position and keeps the size the view already has.
    // Storyboard view controllers bring their size along, programmatically created ones (e.g. a
    // UIHostingController) start out at zero and would slide in invisible without this.
    viewController.view.frame = self.view.bounds;

    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:toLeft onCompletion:nil];
    [self slideIn:viewController fromLeftToRight:toLeft onCompletion:nil];
}

- (void)navigateToRestoreSafeViewController:(BOOL)identityOnly {
    [self showRestoreSafeViewController:identityOnly];
    
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:YES onCompletion:nil];
    [self slideIn:_restoreSafeViewController fromLeftToRight:YES onCompletion:nil];
}

- (void)navigateBackToRestoreOptionDataViewController {
    [self showRestoreOptionDataViewController];
    
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:NO onCompletion:nil];
    [self slideIn:_restoreOptionDataViewController fromLeftToRight:NO onCompletion:nil];
}

- (void)navigateBackToRestoreOptionBackupViewController {
    [self showRestoreOptionBackupViewController];
    
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:NO onCompletion:nil];
    [self slideIn:_restoreOptionBackupViewController fromLeftToRight:NO onCompletion:nil];
}

- (void)navigateBackToSplash {
    UIViewController *current = [self currentVisibleViewController];
    [self slideOut:current fromRightToLeft:NO onCompletion:nil];
    [self slideIn:self fromLeftToRight:NO onCompletion:^{
        [self showPrivacyControls];
    }];
}

- (void)showLoadingHUD {
    if (self.view != nil) {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
}

- (void)hideLoadingHUD {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)resetIDSetupCompletion {
    [_completedIDViewController resetCompletionProcess];
}

- (void)showIdentityCreationError:(NSError *)error {
    UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:error.localizedDescription
                                                                      message:error.localizedFailureReason
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [errAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"try_again"]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction * action) {
        [self.delegate splashViewControllerDidTapSetup:self completionHandler:^{}];
    }]];
    
    if([MFMailComposeViewController canSendMail]) {
        [errAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"contact_support"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(__unused UIAlertAction * action) {
            [self contactSupport:error.localizedDescription];
        }]];
    }
    
    [self presentViewController:errAlert animated:YES completion:nil];
}

#pragma mark - RectUtil

- (CGRect)rect:(CGRect)rect centerIn:(CGRect)outerRect round:(BOOL)round {
    CGFloat innerWidth = rect.size.width;
    CGFloat outerWidth = outerRect.size.width;
    
    CGFloat innerHeight = rect.size.height;
    CGFloat outerHeight = outerRect.size.height;
    
    CGFloat x = (outerWidth - innerWidth) / 2.0;
    CGFloat y = (outerHeight - innerHeight) / 2.0;
    
    if (round) {
        x = roundf(x);
        y = roundf(y);
    }
    
    return CGRectMake(x, y, rect.size.width, rect.size.height);
}

- (CGRect)rect:(CGRect)rect centerHorizontalIn:(CGRect)outerRect round:(BOOL)round {
   CGFloat innerWidth = rect.size.width;
   CGFloat outerWidth = outerRect.size.width;
   
   CGFloat x = (outerWidth - innerWidth) / 2.0;
   if (round)
       x = roundf(x);
   CGFloat y = rect.origin.y;
   
    return CGRectMake(x, y, rect.size.width, rect.size.height);
}

@end
