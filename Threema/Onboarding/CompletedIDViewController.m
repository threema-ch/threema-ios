#import "CompletedIDViewController.h"
#import "UserSettings.h"
#import "ContactStore.h"
#import "MyIdentityStore.h"
#import "ServerAPIConnector.h"
#import "PhoneNumberNormalizer.h"
#import "ProgressLabel.h"
#import "IntroQuestionView.h"
#import "WorkDataFetcher.h"
#import "MDMSetup.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "Threema-Swift.h"
#import "NibUtil.h"
#import "AppDelegate.h"

#define SYNC_TIMEOUT_S 10

@interface CompletedIDViewController () <IntroQuestionDelegate>

@property MyIdentityStore *identityStore;

@property dispatch_semaphore_t syncEmailSemaphore;
@property dispatch_semaphore_t syncPhoneSemaphore;
@property dispatch_semaphore_t syncAdressBookSemaphore;

@property ProgressLabel *emailProgressLabel;
@property ProgressLabel *phoneProgressLabel;
@property ProgressLabel *syncContactsProgressLabel;
@property ProgressLabel *syncSafeProgressLabel;

@property BOOL isProcessing;
@property BOOL hasErrors;

@property NSString *phoneNumber;

@end

@implementation CompletedIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _identityStore = [MyIdentityStore sharedMyIdentityStore];
    
    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateData];
    
    MDMSetup *mdmSetup = [MDMSetup new];
    if ([mdmSetup skipWizard]) {
        [self finishAction:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (void)updateData {
    NSString *nickname = self.setupConfiguration.nickname;
    
    if (nickname.length == 0) {
        nickname = _identityStore.identity;
    }
    
    self.nicknameValue.text = nickname;
    
    if (self.setupConfiguration.linkEmail.length > 0) {
        self.emailValue.text = self.setupConfiguration.linkEmail;
    } else {
        self.emailValue.text = @"-";
    }
    
    if (_identityStore.linkedMobileNo) {
        self.phoneValue.text = _identityStore.linkedMobileNo;
    } else if (self.setupConfiguration.linkPhoneNumber.length > 0) {
        PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
        NSString *prettyMobileNo;
        _phoneNumber = [normalizer phoneNumberToE164:self.setupConfiguration.linkPhoneNumber withDefaultRegion:[PhoneNumberNormalizer userRegion] prettyFormat:&prettyMobileNo];
        
        self.phoneValue.text = prettyMobileNo;
    } else {
        self.phoneValue.text = @"-";
    }
    
    if (self.setupConfiguration.syncContacts) {
        self.syncContactValue.text = [BundleUtil localizedStringForKey:@"On"];
    } else {
        self.syncContactValue.text = [BundleUtil localizedStringForKey:@"Off"];
    }
    
    if (self.setupConfiguration.safePassword != nil && self.setupConfiguration.safePassword.length > 0) {
        self.enableSafeValue.text = [BundleUtil localizedStringForKey:@"On"];
    } else {
        self.enableSafeValue.text = [BundleUtil localizedStringForKey:@"Off"];
    }
}

- (void)adaptToSmallScreen {
    [super adaptToSmallScreen];
    
    CGFloat yOffset = -28.0;
    _nickNameView.frame = CGRectMake(_nickNameView.frame.origin.x, _nickNameView.frame.origin.y + yOffset, _nickNameView.frame.size.width, _nickNameView.frame.size.height);
    
    yOffset -= 8.0;
    _linkedToView.frame = CGRectMake(_linkedToView.frame.origin.x, _linkedToView.frame.origin.y + yOffset, _linkedToView.frame.size.width, _linkedToView.frame.size.height);
    
    yOffset -= 8.0;
    _syncContactsView.frame = CGRectMake(_syncContactsView.frame.origin.x, _syncContactsView.frame.origin.y + yOffset, _syncContactsView.frame.size.width, _syncContactsView.frame.size.height);
    
    yOffset -= 16.0;
    _finishButton.frame = CGRectMake(_finishButton.frame.origin.x, _finishButton.frame.origin.y + yOffset, _finishButton.frame.size.width, _finishButton.frame.size.height);
}

- (void)setup {
    _finishButton.layer.cornerRadius = 3;
    
    _titleLabel.text = [BundleUtil localizedStringForKey:@"id_completed_title"];
    _nickNameLabel.text = [BundleUtil localizedStringForKey:@"id_completed_nickname"];
    _linkedToLabel.text = [BundleUtil localizedStringForKey:@"id_completed_linked_to"];
    _syncContactsLabel.text = [BundleUtil localizedStringForKey:@"id_completed_sync_contacts"];
    _enableSafeLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"safe_setup_backup_title"], TargetManagerObjC.localizedAppName];
    
    [_finishButton setTitle:[BundleUtil localizedStringForKey:@"finish"] forState:UIControlStateNormal];
    _finishButton.accessibilityIdentifier = @"SetupFinishButton";

    self.scrollView.contentSize = self.mainContentView.frame.size;
    
    _finishButton.backgroundColor = UIColor.tintColor;
    [_finishButton setTitleColor:Colors.textProminentButtonWizard forState:UIControlStateNormal];
    
    if ([AppDelegate hasBottomSafeAreaInsets]) {
        BOOL isRegularSizeClass = [AppDelegate sharedAppDelegate].isCompactSizeClass == NO;
        CGFloat regularSizeSpace = isRegularSizeClass ? 50 : 0;
        _finishButton.frame = CGRectMake(_finishButton.frame.origin.x, _finishButton.frame.origin.y - 20.0 - regularSizeSpace, _finishButton.frame.size.width, _finishButton.frame.size.height);
    }
    
    _contactImageView.image = [[UIImage systemImageNamed:@"person.fill"] imageWithTintColor:Colors.textSetup];
    _phoneImageView.image = [[UIImage systemImageNamed:@"phone.fill"] imageWithTintColor:Colors.textSetup];
    _mailImageView.image = [[UIImage systemImageNamed:@"envelope.fill"] imageWithTintColor:Colors.textSetup];
    
    if (!TargetManagerObjC.isBusinessApp) {
        _emailView.hidden = YES;
    }
}

- (void)persistNickname {
    [MyIdentityStore sharedMyIdentityStore].pushFromName = self.setupConfiguration.nickname;
    [[LicenseStore sharedLicenseStore] performUpdateWorkInfo];
}

- (BOOL)linkEmail {
    if (self.setupConfiguration.linkEmail.length < 1) {
        return NO;
    }
    
    if (_identityStore.linkedEmail.length > 0) {
        return NO;
    }
    
    _syncEmailSemaphore = dispatch_semaphore_create(0);
    
    NSString *email = self.setupConfiguration.linkEmail;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showEmailProgress];
    });
    
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn linkEmailWithStore:[MyIdentityStore sharedMyIdentityStore] email:email onCompletion:^(BOOL linked) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_emailProgressLabel hideActivityIndicator];
            
            if (!linked) {
                NSString *message = [BundleUtil localizedStringForKey:@"link_email_sent_title"];
                [_emailProgressLabel showSuccessMessage:message];
                _emailProgressLabel.userInteractionEnabled = NO;
            }
        });
        
        [self signalSemaphore:_syncEmailSemaphore];
    } onError:^(NSError *error) {
        _hasErrors = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_emailProgressLabel showErrorMessage:error.localizedDescription];
        });
        
        [self signalSemaphore:_syncEmailSemaphore];
    }];
    
    dispatch_semaphore_wait(_syncEmailSemaphore, dispatch_time(DISPATCH_TIME_NOW, SYNC_TIMEOUT_S * NSEC_PER_SEC));

    return YES;
}

- (BOOL)linkPhone {
    if (self.setupConfiguration.linkPhoneNumber.length < 1) {
        return NO;
    }
    
    if (_identityStore.linkedMobileNo.length > 0) {
        return NO;
    }
    
    _syncPhoneSemaphore = dispatch_semaphore_create(0);
    
    if (_phoneNumber == nil) {
        // no normalized phone number - ignore (or try _identityStore.createIDPhone??)
        return NO;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showPhoneProgress];
    });
    
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn linkMobileNoWithStore:[MyIdentityStore sharedMyIdentityStore] mobileNo:_phoneNumber onCompletion:^(BOOL linked) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_phoneProgressLabel hideActivityIndicator];
            
            NSString *message = [BundleUtil localizedStringForKey:@"linking_phone_sms_sent"];
            [_phoneProgressLabel showSuccessMessage:message];
            _phoneProgressLabel.userInteractionEnabled = NO;
        });
        
        [self signalSemaphore:_syncPhoneSemaphore];
    } onError:^(NSError *error) {
        _hasErrors = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_phoneProgressLabel showErrorMessage:error.localizedDescription];
        });
        
        [self signalSemaphore:_syncPhoneSemaphore];
    }];
    
    dispatch_semaphore_wait(_syncPhoneSemaphore, dispatch_time(DISPATCH_TIME_NOW, SYNC_TIMEOUT_S * NSEC_PER_SEC));
    
    return YES;
}

- (BOOL)syncAdressBook {
    [UserSettings sharedUserSettings].syncContacts = self.setupConfiguration.syncContacts;
    
    if (self.setupConfiguration.syncContacts == NO) {
        return NO;
    }
    
    _syncAdressBookSemaphore = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showContactsProgress:_syncContactsView progressValue:_syncContactValue progressText:[BundleUtil localizedStringForKey:@"syncing_contacts"]];
    });
    
    [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES onCompletion:^(BOOL addressBookAccessGranted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *message = [BundleUtil localizedStringForKey:@"Done"];
            [_syncContactsProgressLabel showSuccessMessage:message];
        });
        
        [self signalSemaphore:_syncAdressBookSemaphore];
    } onError:^(NSError *error) {
        _hasErrors = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_syncContactsProgressLabel showErrorMessage:error.localizedDescription];
        });
        
        [self signalSemaphore:_syncAdressBookSemaphore];
    }];
    
    dispatch_semaphore_wait(_syncAdressBookSemaphore, dispatch_time(DISPATCH_TIME_NOW, SYNC_TIMEOUT_S * NSEC_PER_SEC));

    return YES;
}

- (void)enableSafeWithCompletion:(nullable void(^)(BOOL enabled))onCompletion {
    SafeConfigManager *safeConfigManager = [[SafeConfigManager alloc] init];
    BusinessInjector * bi = [BusinessInjector new];
    SafeStore *safeStore = [[SafeStore alloc] initWithSafeConfigManagerAsObject:safeConfigManager serverApiConnector:[[ServerAPIConnector alloc] init] groupManager: [bi groupManagerObjC] myIdentityStore: bi.myIdentityStore];
    SafeManager *safeManager = [[SafeManager alloc] initWithSafeConfigManagerAsObject:safeConfigManager safeStore:safeStore safeAPIService:[[SafeApiService alloc] init]];
    
    // apply Threema Safe password and server config from MDM
    MDMSetup *mdmSetup = [MDMSetup new];
    NSString *customServer = nil;
    NSString *customServerUsername = nil;
    NSString *customServerPassword = nil;
    NSNumber *maxBackupBytes = nil;
    NSNumber *retentionDays = nil;
    
    if ([mdmSetup isSafeBackupPasswordPreset]) {
        self.setupConfiguration.safePassword = [mdmSetup safePassword];
    }
    
    if ([mdmSetup isSafeBackupServerPreset]) {
        customServer = [mdmSetup safeServerUrl];
        customServerUsername = [mdmSetup safeServerUsername];
        customServerPassword = [mdmSetup safeServerPassword];

        // Set data to safeConfigManager in case of empty or to short password
        [safeConfigManager setCustomServer:customServer];
        [safeConfigManager setServer:customServer];
    } else if (self.setupConfiguration.safeCustomServer != nil) {
        customServer = self.setupConfiguration.safeCustomServer;
        customServerUsername = self.setupConfiguration.safeServerUsername;
        customServerPassword = self.setupConfiguration.safeServerPassword;
        maxBackupBytes = self.setupConfiguration.safeMaxBackupBytes;
        retentionDays = self.setupConfiguration.safeRetentionDays;
    }
        
    if (self.setupConfiguration.safePassword == nil || self.setupConfiguration.safePassword.length < 8) {
        [safeManager deactivate];
        onCompletion(NO);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showSafeProgress:_enableSafeView progressValue:_enableSafeValue progressText:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"safe_preparing"], TargetManagerObjC.localizedAppName]];
    });
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [safeManager activateWithIdentity:self.identityStore.identity safePassword:self.setupConfiguration.safePassword customServer:customServer serverUser:customServerUsername serverPassword:customServerPassword server:nil maxBackupBytes:maxBackupBytes retentionDays:retentionDays completion:^(NSError * _Nullable error) {
            if (error != nil) {
                _hasErrors = YES;
                [_syncSafeProgressLabel showErrorMessage:error.localizedDescription];
                onCompletion(NO);
            } else {
                NSString *message = [BundleUtil localizedStringForKey:@"Done"];
                [_syncSafeProgressLabel showSuccessMessage:message];
                onCompletion(YES);
            }
            return;
        }];
    });
}

- (void)signalSemaphore:(dispatch_semaphore_t)semaphore {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_semaphore_signal(semaphore);
    });
}

- (void)arrangeViewsForCompletion {
    
    CGFloat addedPhoneHeight = _phoneView.frame.size.height;
    CGFloat addedEmailHeight = _emailView.frame.size.height;
    
    // double size of email & phone fields
    _phoneView.frame = CGRectMake(_phoneView.frame.origin.x, _phoneView.frame.origin.y, _phoneView.frame.size.width, _phoneView.frame.size.height + addedPhoneHeight);
    _emailView.frame = CGRectMake(_emailView.frame.origin.x, _emailView.frame.origin.y, _emailView.frame.size.width, _emailView.frame.size.height + addedEmailHeight);
    
    _linkedToView.frame = CGRectMake(_linkedToView.frame.origin.x, _linkedToView.frame.origin.y, _linkedToView.frame.size.width, _linkedToView.frame.size.height + addedPhoneHeight + addedEmailHeight);
    
    [UIView animateWithDuration:0.4 delay:0 options:0 animations:^{
        //hide title and increase content (scroll) section
        _titleLabel.alpha = 0.0;
        _scrollView.frame = CGRectMake(_scrollView.frame.origin.x, _scrollView.frame.origin.y - _titleLabel.frame.size.height, _scrollView.frame.size.width, _scrollView.frame.size.height + _titleLabel.frame.size.height);

        CGFloat yOffset = 0;
        _nickNameView.frame = CGRectMake(_nickNameView.frame.origin.x, _nickNameView.frame.origin.y + yOffset, _nickNameView.frame.size.width, _nickNameView.frame.size.height);
        
        _linkedToView.frame = CGRectMake(_linkedToView.frame.origin.x, _linkedToView.frame.origin.y + yOffset, _linkedToView.frame.size.width, _linkedToView.frame.size.height);
        
        _emailView.frame = CGRectMake(_emailView.frame.origin.x, _emailView.frame.origin.y + addedPhoneHeight, _emailView.frame.size.width, _emailView.frame.size.height);
        
        _syncContactsView.frame = CGRectMake(_syncContactsView.frame.origin.x, _syncContactsView.frame.origin.y + addedPhoneHeight, _syncContactsView.frame.size.width, _syncContactsView.frame.size.height);

        _enableSafeView.frame = CGRectMake(_enableSafeView.frame.origin.x, _enableSafeView.frame.origin.y + addedPhoneHeight, _enableSafeView.frame.size.width, _enableSafeView.frame.size.height);
        
        _finishButton.frame = CGRectMake(_finishButton.frame.origin.x, _finishButton.frame.origin.y + -yOffset, _finishButton.frame.size.width, _finishButton.frame.size.height);

        [self.containerDelegate hideControls:YES];
    } completion:nil];
}

- (void)showEmailProgress {
    CGFloat yPos = CGRectGetMaxY(_emailValue.frame);
    
    CGRect labelRect = CGRectMake(_emailValue.frame.origin.x, yPos, _emailValue.frame.size.width, _emailValue.frame.size.height);
    
    _emailProgressLabel = [[ProgressLabel alloc] initWithFrame:labelRect];
    _emailProgressLabel.backgroundColor = [UIColor clearColor];
    _emailProgressLabel.font = [_emailValue.font fontWithSize:14.0];
    _emailProgressLabel.textColor = _emailValue.textColor;
    _emailProgressLabel.alpha = 0.0;
    _emailProgressLabel.text = [BundleUtil localizedStringForKey:@"linking_email"];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedEmailProgress)];
    [_emailProgressLabel addGestureRecognizer:tapGesture];
    
    [_emailView addSubview:_emailProgressLabel];
    
    [UIView animateWithDuration:0.4 delay:0 options:0 animations:^{
        _emailProgressLabel.alpha = 1.0;
        
        [_emailProgressLabel showActivityIndicator];
    } completion:nil];
}

- (void)showPhoneProgress {
    CGFloat yPos = CGRectGetMaxY(_phoneValue.frame);
    CGRect labelRect = CGRectMake(_phoneValue.frame.origin.x, yPos, _phoneValue.frame.size.width, _phoneValue.frame.size.height);
    
    _phoneProgressLabel = [[ProgressLabel alloc] initWithFrame:labelRect];
    _phoneProgressLabel.backgroundColor = [UIColor clearColor];
    _phoneProgressLabel.font = [_phoneValue.font fontWithSize:14.0];
    _phoneProgressLabel.textColor = _phoneValue.textColor;
    _phoneProgressLabel.alpha = 0.0;
    _phoneProgressLabel.text = [BundleUtil localizedStringForKey:@"linking_phone"];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedPhoneProgress)];
    [_phoneProgressLabel addGestureRecognizer:tapGesture];
    
    [_phoneView addSubview:_phoneProgressLabel];
    
    [UIView animateWithDuration:0.4 delay:0 options:0 animations:^{
        _phoneProgressLabel.alpha = 1.0;
        
        [_phoneProgressLabel showActivityIndicator];
    } completion:nil];
}

- (void)showContactsProgress:(UIView*)container progressValue:(UILabel*)value progressText:(NSString*)text {
    CGRect labelRect = value.frame;
    
    _syncContactsProgressLabel = [[ProgressLabel alloc] initWithFrame:labelRect];
    _syncContactsProgressLabel.backgroundColor = [UIColor clearColor];
    _syncContactsProgressLabel.font = [value.font fontWithSize:14.0];
    _syncContactsProgressLabel.textColor = value.textColor;
    
    _syncContactsProgressLabel.alpha = 0.0;
    _syncContactsProgressLabel.text = text;
    
    [container addSubview:_syncContactsProgressLabel];
    
    [UIView animateWithDuration:0.4 delay:0 options:0 animations:^{
        value.alpha = 0.0;
        _syncContactsProgressLabel.alpha = 1.0;
        
        [_syncContactsProgressLabel showActivityIndicator];
    } completion:nil];
}

- (void)showSafeProgress:(UIView*)container progressValue:(UILabel*)value progressText:(NSString*)text {
    CGRect labelRect = value.frame;
    
    _syncSafeProgressLabel = [[ProgressLabel alloc] initWithFrame:labelRect];
    _syncSafeProgressLabel.backgroundColor = [UIColor clearColor];
    _syncSafeProgressLabel.font = [value.font fontWithSize:14.0];
    _syncSafeProgressLabel.textColor = value.textColor;
    
    _syncSafeProgressLabel.alpha = 0.0;
    _syncSafeProgressLabel.text = text;
    
    [container addSubview:_syncSafeProgressLabel];
    
    [UIView animateWithDuration:0.4 delay:0 options:0 animations:^{
        value.alpha = 0.0;
        _syncSafeProgressLabel.alpha = 1.0;
        
        [_syncSafeProgressLabel showActivityIndicator];
    } completion:nil];
}

- (BOOL)isInputValid {
    if (_isProcessing) {
        return NO;
    }
    
    return YES;
}

- (IBAction)finishAction:(id)sender {
    if (_isProcessing == NO) {
        _isProcessing = YES;
        [self startCompletionProcess];
    } else {
        [self finishCompletionProcess];
    }
}

- (void)startCompletionProcess {
    #if SCENE_DELEGATE_ROOT_COORDINATOR_DEVELOPMENT
    [_delegate completedIDSetupWithConfiguration:self.setupConfiguration];
    return;
    #endif
    
    _finishButton.userInteractionEnabled = NO;
    _finishButton.alpha = 0.0;
    
    [self arrangeViewsForCompletion];
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // Run migration if needed
    [SetupApp runDatabaseMigrationIfNeededWithRemoteSecretAndKeychain:self.setupConfiguration.remoteSecretAndKeychain completionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            [ErrorHandler abortWithError:error];
            return;
        }

        [SetupApp runAppMigrationIsNeededWithCompletionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                [ErrorHandler abortWithError:error];
                return;
            }

            // Set new identity feature mask
            [FeatureMask updateLocalObjc];

            [MBProgressHUD hideHUDForView:self.view animated:YES];

            [AppSetup setState:AppSetupStateIdentitySetupComplete];

            // From now on all business objects can be used as usual

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                __block NSInteger timeout = 2000;

                [self persistNickname];

                if ([self linkPhone]) {
                    timeout += 1000;
                }

                if ([self linkEmail]) {
                    timeout += 1000;
                }

                if ([self syncAdressBook]) {
                    timeout += 500;
                }

                [self enableSafeWithCompletion:^(BOOL enabled) {
                    if (enabled) {
                        timeout += 500;
                    }

                    // Do not show Threema Safe Intro after setup wizard
                    [[UserSettings sharedUserSettings] setSafeIntroShown:YES];

                    if (_hasErrors == NO) {
                        // No errors - continue after timeout
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                            [_delegate completedIDSetup];
                        });
                    } else {
                        // User needs to confirm
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [_finishButton setTitle:[BundleUtil localizedStringForKey:@"Done"] forState:UIControlStateNormal];
                            _finishButton.userInteractionEnabled = YES;
                            _finishButton.alpha = 1.0;
                        });
                    }

                    _identityStore.createIDPhone = nil;
                    _identityStore.createIDEmail = nil;
                }];
            });
        }];
    }];
}

- (void)finishCompletionProcess {
    #if SCENE_DELEGATE_ROOT_COORDINATOR_DEVELOPMENT
    [_delegate completedIDSetupWithConfiguration:self.setupConfiguration];
    return;
    #endif
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate completedIDSetup];
    });
}

#pragma mark - gesture recognizers

- (void)tappedPhoneProgress {
    [self showErrorText:_phoneProgressLabel.text];
}

- (void)tappedEmailProgress {
    [self showErrorText:_emailProgressLabel.text];
}

- (void)showErrorText:(NSString *)errorText {
    IntroQuestionView *view = (IntroQuestionView *)[NibUtil loadViewFromNibWithName:@"IntroQuestionView"];
    view.showOnlyOkButton = YES;
    view.questionLabel.text = errorText;
    view.delegate = self;
    view.frame = [self rect:view.frame centerIn:self.view.frame round:YES];
    
    [self.view addSubview:view];
    
    [self showMessageView:view];
}

- (void)selectedOk:(IntroQuestionView *)sender {
    [self hideMessageView:sender ignoreControls:YES];
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

@end
