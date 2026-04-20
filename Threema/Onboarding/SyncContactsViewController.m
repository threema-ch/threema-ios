#import "SyncContactsViewController.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "MDMSetup.h"

@interface SyncContactsViewController ()

@end

@implementation SyncContactsViewController {
    MDMSetup *mdmSetup;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        mdmSetup = [MDMSetup new];
   }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.syncContactsSwitch.on = YES;

    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]) {
        self.syncContactsSwitch.on = [mdmSetup contactSync];
        self.syncContactsSwitch.enabled = false;
    } else {
        self.setupConfiguration.syncContacts = self.syncContactsSwitch.on;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (IBAction)syncContactSwitchChanged:(id)sender {
    self.setupConfiguration.syncContacts = _syncContactsSwitch.on;
}

- (void)setup {
    if (TargetManagerObjC.isBusinessApp) {
        _titleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_sync_title_work"], TargetManagerObjC.appName];
        _descriptionLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_sync_description_work"], TargetManagerObjC.appName];
    } else {
        _titleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_sync_title"], TargetManagerObjC.appName];
        _descriptionLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_sync_description"], TargetManagerObjC.appName];
    }
    _syncContactsLabel.text = [BundleUtil localizedStringForKey:@"id_sync_contacts"];

    self.moreView.mainView = self.mainContentView;
    self.moreView.moreMessageText = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"more_information_sync_contacts"], TargetManagerObjC.appName];
    
    _syncContactsView.layer.cornerRadius = 3;
    _syncContactsView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _syncContactsView.layer.borderWidth = 0.5;
    self.syncContactsSwitch.enabled = ![mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC];
    
    _syncContactsSwitch.onTintColor = UIColor.tintColor;
}

- (BOOL)isInputValid {
    if ([self.moreView isShown]) {
        return NO;
    }
    
    return YES;
}

@end
