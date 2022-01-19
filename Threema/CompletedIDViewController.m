//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "CompletedIDViewController.h"
#import "UserSettings.h"
#import "ContactStore.h"
#import "MyIdentityStore.h"
#import "ServerAPIConnector.h"
#import "PhoneNumberNormalizer.h"
#import "RectUtil.h"
#import "ProgressLabel.h"
#import "IntroQuestionView.h"
#import "WorkDataFetcher.h"
#import "MDMSetup.h"
#import "Threema-Swift.h"
#import "ConversationUtils.h"
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
@property ProgressLabel *syncProgressLabel;

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
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    if ([mdmSetup skipWizard]) {
        [self finishAction:nil];
    }
}

- (void)updateData {
    NSString *nickname = _identityStore.pushFromName;
    
    if (nickname.length == 0) {
        nickname = _identityStore.identity;
    }
    
    self.nicknameValue.text = nickname;
    
    if (_identityStore.createIDEmail.length > 0) {
        self.emailValue.text = _identityStore.createIDEmail;
    } else {
        self.emailValue.text = @"-";
    }
    
    if (_identityStore.linkedMobileNo) {
        self.phoneValue.text = _identityStore.createIDPhone;
    } else if (_identityStore.createIDPhone.length > 0) {
        PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
        NSString *prettyMobileNo;
        _phoneNumber = [normalizer phoneNumberToE164:_identityStore.createIDPhone withDefaultRegion:[PhoneNumberNormalizer userRegion] prettyFormat:&prettyMobileNo];
        
        self.phoneValue.text = prettyMobileNo;
    } else {
        self.phoneValue.text = @"-";
    }
    
    if ([UserSettings sharedUserSettings].syncContacts) {
        self.syncContactValue.text = [BundleUtil localizedStringForKey:@"On"];
    } else {
        self.syncContactValue.text = [BundleUtil localizedStringForKey:@"Off"];
    }
    if (_identityStore.tempSafePassword != nil && _identityStore.tempSafePassword.length > 0) {
        self.enableSafeValue.text = [BundleUtil localizedStringForKey:@"On"];
    } else {
        self.enableSafeValue.text = [BundleUtil localizedStringForKey:@"Off"];
    }
}

- (void)adaptToSmallScreen {
    [super adaptToSmallScreen];
    
    CGFloat yOffset = -28.0;
    _nickNameView.frame = [RectUtil offsetRect:_nickNameView.frame byX:0.0 byY:yOffset];
    
    yOffset -= 8.0;
    _linkedToView.frame = [RectUtil offsetRect:_linkedToView.frame byX:0.0 byY:yOffset];
    
    yOffset -= 8.0;
    _syncContactsView.frame = [RectUtil offsetRect:_syncContactsView.frame byX:0.0 byY:yOffset];
    
    yOffset -= 16.0;
    _finishButton.frame = [RectUtil offsetRect:_finishButton.frame byX:0.0 byY:yOffset];
}

- (void)setup {
    _finishButton.layer.cornerRadius = 3;
    
    _titleLabel.text = [BundleUtil localizedStringForKey:@"id_completed_title"];
    _nickNameLabel.text = [BundleUtil localizedStringForKey:@"id_completed_nickname"];
    _linkedToLabel.text = [BundleUtil localizedStringForKey:@"id_completed_linked_to"];
    _syncContactsLabel.text = [BundleUtil localizedStringForKey:@"id_completed_sync_contacts"];
    _enableSafeLabel.text = [BundleUtil localizedStringForKey:@"safe_setup_backup_title"];
    
    [_finishButton setTitle:[BundleUtil localizedStringForKey:@"finish"] forState:UIControlStateNormal];
    
    self.scrollView.contentSize = self.mainContentView.frame.size;
    
    _finishButton.backgroundColor = [Colors mainThemeDark];
    [_finishButton setTitleColor:[Colors white] forState:UIControlStateNormal];
    
    if ([AppDelegate hasBottomSafeAreaInsets]) {
        CGFloat iPadSpace = SYSTEM_IS_IPAD ? 50 : 0;
        _finishButton.frame = CGRectMake(_finishButton.frame.origin.x, _finishButton.frame.origin.y - 20.0 - iPadSpace, _finishButton.frame.size.width, _finishButton.frame.size.height);
    }
    
    UIImage *contactImage = [BundleUtil imageNamed:@"Contact"];
    _contactImageView.image = [contactImage imageWithTint:[Colors white]];
    
    _phoneImageView.image = [UIImage imageNamed:@"Phone" inColor:[Colors white]];
    _mailImageView.image = [UIImage imageNamed:@"Mail" inColor:[Colors white]];
    
    if (![LicenseStore requiresLicenseKey]) {
        _emailView.hidden = YES;
    }
}

- (void)resetPersistedIDCreateState {
    _identityStore.pendingCreateID = NO;
}

- (BOOL)linkEmail {
    if (_identityStore.createIDEmail.length < 1) {
        return NO;
    }
    
    if (_identityStore.linkedEmail.length > 0) {
        return NO;
    }
    
    _syncEmailSemaphore = dispatch_semaphore_create(0);
    
    NSString *email = _identityStore.createIDEmail;
    
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
    if (_identityStore.createIDPhone.length < 1) {
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
    if ([UserSettings sharedUserSettings].syncContacts == NO) {
        return NO;
    }
    
    _syncAdressBookSemaphore = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgress:_syncContactsView progressValue:_syncContactValue progressText:[BundleUtil localizedStringForKey:@"syncing_contacts"]];
    });
    
    [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES onCompletion:^(BOOL addressBookAccessGranted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *message = [BundleUtil localizedStringForKey:@"Done"];
            [_syncProgressLabel showSuccessMessage:message];
        });
        
        [self signalSemaphore:_syncAdressBookSemaphore];
    } onError:^(NSError *error) {
        _hasErrors = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_syncProgressLabel showErrorMessage:error.localizedDescription];
        });
        
        [self signalSemaphore:_syncAdressBookSemaphore];
    }];
    
    dispatch_semaphore_wait(_syncAdressBookSemaphore, dispatch_time(DISPATCH_TIME_NOW, SYNC_TIMEOUT_S * NSEC_PER_SEC));

    return YES;
}

- (BOOL)enableSafe {
    SafeConfigManager *safeConfigManager = [[SafeConfigManager alloc] init];
    SafeStore *safeStore = [[SafeStore alloc] initWithSafeConfigManagerAsObject:safeConfigManager serverApiConnector:[[ServerAPIConnector alloc] init]];
    SafeManager *safeManager = [[SafeManager alloc] initWithSafeConfigManagerAsObject:safeConfigManager safeStore:safeStore safeApiService:[[SafeApiService alloc] init]];
    
    // apply Threema Safe password and server config from MDM
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    if ([mdmSetup isSafeBackupPasswordPreset]) {
        self.identityStore.tempSafePassword = [mdmSetup safePassword];
    }
    
    if ([mdmSetup isSafeBackupServerPreset]) {
        [safeConfigManager setCustomServer:[mdmSetup safeServerUrl]];
        [safeConfigManager setServer:[safeStore composeSafeServerAuthWithServer:[mdmSetup safeServerUrl] user:[mdmSetup safeServerUsername] password:[mdmSetup safeServerPassword]].absoluteString];
    }
    
    
    if (self.identityStore.tempSafePassword == nil || self.identityStore.tempSafePassword.length < 8) {
        [safeManager deactivate];
        return NO;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgress:_enableSafeView progressValue:_enableSafeValue progressText:[BundleUtil localizedStringForKey:@"safe_preparing"]];
    });
    
    NSError *__autoreleasing  _Nullable * _Nullable error = NULL;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [safeManager activateWithIdentity:self.identityStore.identity password:self.identityStore.tempSafePassword error:error];
    });
    
    if (error != nil) {
        _hasErrors = YES;
        return NO;
    } else {
        return YES;
    }
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
    _phoneView.frame = [RectUtil changeSizeOf:_phoneView.frame deltaX:0.0 deltaY:addedPhoneHeight];
    _emailView.frame = [RectUtil changeSizeOf:_emailView.frame deltaX:0.0 deltaY:addedEmailHeight];
    
    _linkedToView.frame = [RectUtil changeSizeOf:_linkedToView.frame deltaX:0.0 deltaY:addedPhoneHeight + addedEmailHeight];
    
    [UIView animateWithDuration:0.4 delay:0 options:0 animations:^{
        //hide title and increase content (scroll) section
        _titleLabel.alpha = 0.0;
        _scrollView.frame = CGRectMake(_scrollView.frame.origin.x, _scrollView.frame.origin.y - _titleLabel.frame.size.height, _scrollView.frame.size.width, _scrollView.frame.size.height + _titleLabel.frame.size.height);

        CGFloat yOffset = 0;
        _nickNameView.frame = [RectUtil offsetRect:_nickNameView.frame byX:0.0 byY:yOffset];
        
        _linkedToView.frame = [RectUtil offsetRect:_linkedToView.frame byX:0.0 byY:yOffset];
        
        _emailView.frame = [RectUtil offsetRect:_emailView.frame byX:0.0 byY:addedPhoneHeight];
        
        _syncContactsView.frame = [RectUtil offsetRect:_syncContactsView.frame byX:0.0 byY:addedPhoneHeight];

        _enableSafeView.frame = [RectUtil offsetRect:_enableSafeView.frame byX:0.0 byY:addedPhoneHeight];
        
        _finishButton.frame = [RectUtil offsetRect:_finishButton.frame byX:0.0 byY:-yOffset];

        [self.containerDelegate hideControls:YES];
    } completion:nil];
}

- (void)showEmailProgress {
    CGFloat yPos = CGRectGetMaxY(_emailValue.frame);
    
    CGRect labelRect = [RectUtil setYPositionOf:_emailValue.frame y:yPos];
    
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
    
    CGRect labelRect = [RectUtil setYPositionOf:_phoneValue.frame y:yPos];
    
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

- (void) showProgress:(UIView*)container progressValue:(UILabel*)value progressText:(NSString*)text {
    CGRect labelRect = value.frame;
    
    _syncProgressLabel = [[ProgressLabel alloc] initWithFrame:labelRect];
    _syncProgressLabel.backgroundColor = [UIColor clearColor];
    _syncProgressLabel.font = [value.font fontWithSize:14.0];
    _syncProgressLabel.textColor = value.textColor;
    
    _syncProgressLabel.alpha = 0.0;
    _syncProgressLabel.text = text;
    
    [container addSubview:_syncProgressLabel];
    
    [UIView animateWithDuration:0.4 delay:0 options:0 animations:^{
        value.alpha = 0.0;
        _syncProgressLabel.alpha = 1.0;
        
        [_syncProgressLabel showActivityIndicator];
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
    _finishButton.userInteractionEnabled = NO;
    _finishButton.alpha = 0.0;
    
    [self resetPersistedIDCreateState];
    
    [self arrangeViewsForCompletion];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSInteger timout = 2000;
        
        if ([self linkPhone]) {
            timout += 1000;
        }
        
        if ([self linkEmail]) {
            timout += 1000;
        }

        if ([self syncAdressBook]) {
            timout += 500;
        }
        
        if ([self enableSafe]) {
            timout += 500;
        }
        
        // do not show Threema Safe Intro after setup wizard
        [[UserSettings sharedUserSettings] setSafeIntroShown:YES];

        if (_hasErrors == NO) {
            // no errors - continue after timeout
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timout * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                [_delegate completedIDSetup];
            });
        } else {
            // user needs to confirm
            dispatch_async(dispatch_get_main_queue(), ^{
                [_finishButton setTitle:[BundleUtil localizedStringForKey:@"Done"] forState:UIControlStateNormal];
                _finishButton.userInteractionEnabled = YES;
                _finishButton.alpha = 1.0;
            });
        }
        
        _identityStore.createIDPhone = nil;
        _identityStore.createIDEmail = nil;
        _identityStore.tempSafePassword = nil;
    });
}

- (void)finishCompletionProcess {
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
    view.frame = [RectUtil rect:view.frame centerIn:self.view.frame round:YES];
    
    [self.view addSubview:view];
    
    [self showMessageView:view];
}

- (void)selectedOk:(IntroQuestionView *)sender {
    [self hideMessageView:sender ignoreControls:YES];
}

@end
