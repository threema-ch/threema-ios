#import "CompletedIDViewController.h"
#import "MyIdentityStore.h"
#import "MDMSetup.h"
#import "Threema-Swift.h"

@interface CompletedIDViewController ()

@property MyIdentityStore *identityStore;

@property BOOL isProcessing;

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
        PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer new];
        self.phoneNumber = [normalizer e164FormatFrom:self.setupConfiguration.linkPhoneNumber defaultRegion:normalizer.userRegion];
        self.phoneValue.text = [normalizer prettyFormatFrom:self.setupConfiguration.linkPhoneNumber defaultRegion:normalizer.userRegion];
    } else {
        self.phoneValue.text = @"-";
    }
    
    if (self.setupConfiguration.syncContacts) {
        self.syncContactValue.text = [BundleUtil localizedStringForKey:@"on"];
    } else {
        self.syncContactValue.text = [BundleUtil localizedStringForKey:@"off"];
    }
    
    if (self.setupConfiguration.safePassword != nil && self.setupConfiguration.safePassword.length > 0) {
        self.enableSafeValue.text = [BundleUtil localizedStringForKey:@"on"];
    } else {
        self.enableSafeValue.text = [BundleUtil localizedStringForKey:@"off"];
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
    
    CGFloat bottomInset = self.view.safeAreaInsets.bottom;
    if (bottomInset > 0) {
        BOOL isRegularSizeClass =
            self.view.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
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

- (BOOL)isInputValid {
    if (_isProcessing) {
        return NO;
    }
    
    return YES;
}

- (IBAction)finishAction:(id)sender {
    // The setup completion runs asynchronously in the coordinator. Ignore any further taps until it
    // either finished or failed, otherwise the completion steps would run more than once.
    if (_isProcessing) {
        return;
    }

    _isProcessing = YES;

    // Immediate feedback: the coordinator adds a spinner on top of the wizard, but the completion
    // steps (Safe setup, contact sync, ...) take a while and paging back mid-setup must not happen
    _finishButton.enabled = NO;
    [self.containerDelegate hideControls:YES];

    [_delegate completedIDSetupWithConfiguration:self.setupConfiguration];
}

- (void)resetCompletionProcess {
    _isProcessing = NO;
    _finishButton.enabled = YES;
    [self.containerDelegate hideControls:NO];
}

@end
