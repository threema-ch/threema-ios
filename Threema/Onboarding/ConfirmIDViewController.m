#import "ConfirmIDViewController.h"
#import "MyIdentityStore.h"
#import "LicenseStore.h"
#import "ThreemaFramework.h"

@interface ConfirmIDViewController ()

@end

@implementation ConfirmIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.idLabel.text = [MyIdentityStore sharedMyIdentityStore].identity;
}

- (void)viewDidAppear:(BOOL)animated {
    // This fixes an issue where the viewDidAppear() of SafeViewController.swift gets called to soon.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
    });
}

- (void)setup {
    _titleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"welcome"], TargetManagerObjC.appName];

    if (TargetManagerObjC.isBusinessApp) {
        _descriptionLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_confirm_description_work"], TargetManagerObjC.localizedAppName];
    } else {
        _descriptionLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_confirm_description"], TargetManagerObjC.localizedAppName];
    }
    _yourIdLabel.text =[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_confirm_your_id"], TargetManagerObjC.localizedAppName];

    self.moreView.mainView = self.mainContentView;
    self.moreView.moreMessageText = [BundleUtil localizedStringForKey:@"more_information_confirm_id"];
    
    _idLabel.textColor = UIColor.tintColor;
}

- (BOOL)isInputValid {
    if ([self.moreView isShown]) {
        return NO;
    }
    
    return YES;
}

@end
