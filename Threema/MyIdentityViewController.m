//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import <MobileCoreServices/UTCoreTypes.h>

#import "MyIdentityViewController.h"
#import "MyIdentityStore.h"
#import "ScanIdentityController.h"
#import "ServerAPIConnector.h"
#import "KKPasscodeLock.h"
#import "ContactStore.h"
#import "PasswordCallback.h"
#import "CreatePasswordTrigger.h"
#import "BackupIdentityViewController.h"
#import "MBProgressHUD.h"
#import "RevocationKeyHandler.h"
#import "QRCodeGenerator.h"
#import "NSString+Hex.h"
#import "UserReminder.h"
#import "AppDelegate.h"
#import "UIImage+ColoredImage.h"
#import "BundleUtil.h"
#import "LicenseStore.h"
#import "BrandingUtils.h"
#import "UserSettings.h"
#import "AvatarMaker.h"
#import "FullscreenImageViewController.h"
#import "ModalNavigationController.h"
#import "ValidationLogger.h"
#import "MDMSetup.h"
#import "Threema-Swift.h"
#import "ActivityUtil.h"

#define SEGUE_NICKNAME @"EditProfile"
#define SEGUE_SAFE_SETUP @"segueSafeSetup"
#define THREEMA_ID_SHARE_LINK @"https://threema.id/"

@interface MyIdentityViewController () <PasswordCallback, UIScrollViewDelegate, ModalNavigationControllerDelegate>

@property RevocationKeyHandler *revocationKeyHandler;

@end

@implementation MyIdentityViewController {
    UIView *coverView;
    UIImageView *zoomingQrImageView;
    CGRect qrRect;
    CGRect qrZoomedRect;

    UIAlertController *deleteActionSheet;
    
    MDMSetup *mdmSetup;
}

@synthesize nickNameTitleLabel;
@synthesize threemaIdTitleLabel;
@synthesize threemaIdLabel;
@synthesize threemaSafeLabel;
@synthesize nickNameLabel;
@synthesize keyFingerprintLabel;
@synthesize qrBackgroundImageView;

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    }
    return self;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[ModalNavigationController class]]) {
        ModalNavigationController *nav = segue.destinationViewController;
        nav.modalDelegate = self;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.interactivePopGestureRecognizer.enabled  = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;

    if (![ScanIdentityController canScan])
        self.navigationItem.rightBarButtonItem = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateView) name:@"ThreemaIdentityLinkedWithMobileNo" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];

    _revocationKeyHandler = [[RevocationKeyHandler alloc] init];

    [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];

    UITapGestureRecognizer *imageTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedHeaderView)];
    [_imageView addGestureRecognizer:imageTapRecognizer];
    _imageView.accessibilityTraits = UIAccessibilityTraitButton;
    _imageView.isAccessibilityElement = NO;

    UITapGestureRecognizer *editTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedHeaderView)];
    [_editButton addGestureRecognizer:editTapRecognizer];
    _editButton.accessibilityTraits = UIAccessibilityTraitNone;
    _editButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"edit_profile"];
    
    UITapGestureRecognizer *qrCodeTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showFullScreenQrView)];
    [_qrCodeButton addGestureRecognizer:qrCodeTapRecognizer];
    _qrCodeButton.accessibilityTraits = UIAccessibilityTraitNone;
    _qrCodeButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"qr_code"];
    
    UITapGestureRecognizer *shareIdTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedShareThreemaId)];
    [_shareIdButton addGestureRecognizer:shareIdTapRecognizer];
    _shareIdButton.accessibilityTraits = UIAccessibilityTraitNone;
    _shareIdButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"share_id"];
    
    if (@available(iOS 11.0, *)) {
        _imageView.accessibilityIgnoresInvertColors = true;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }

    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)appForeground:(NSNotification*)notification {
    /* must update view as the user may have come back from doing e-mail verification */
    [self updateView];
}

- (void)appResignActive:(NSNotification*)notification {
    [self hideFullScreenQrViewAnimated:NO];
}

- (void)colorThemeChanged:(NSNotification*)notification {
    [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
    [self updateColors];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self hideFullScreenQrViewAnimated:NO];
    [self updateView];

    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = [UserSettings sharedUserSettings].largeTitleDisplayMode;
    }
    
    // iOS fix where the logo is moved to the right sometimes
    if (self.navigationController.navigationBar.frame.size.height == 44.0 && [LicenseStore requiresLicenseKey]) {
        [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
    }
    else if (self.navigationController.navigationBar.frame.size.height == 44.0 && ![LicenseStore requiresLicenseKey] && self.navigationItem.titleView != nil) {
        [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [self hideFullScreenQrViewAnimated:NO];

    [super viewWillDisappear:animated];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    UIView *header = self.tableView.tableHeaderView;
    if (header) {
        CGSize newSize = [header systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        header.frame = CGRectMake(header.frame.origin.x, header.frame.origin.y, header.frame.size.width, newSize.height);
    }
}


- (void)updatePendingEmailLink {
    /* check status of e-mail link */
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn checkLinkEmailStatus:[MyIdentityStore sharedMyIdentityStore] email:[MyIdentityStore sharedMyIdentityStore].linkedEmail onCompletion:^(BOOL linked) {
        if (linked) {
            [MyIdentityStore sharedMyIdentityStore].linkEmailPending = NO;
            self.linkedEmailLabel.text = [MyIdentityStore sharedMyIdentityStore].linkedEmail;
        }
    } onError:^(NSError *error) {}];
}

- (void)updateView {
    _scanQrCodeBarButtonItem.accessibilityLabel = [BundleUtil localizedStringForKey:@"scan_identity"];
    threemaIdLabel.text = [MyIdentityStore sharedMyIdentityStore].identity;
    threemaIdLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"my_threema_id", @""), [MyIdentityStore sharedMyIdentityStore].identity];

    keyFingerprintLabel.text = [MyIdentityStore sharedMyIdentityStore].keyFingerprint;

    UIImage *qrCodeImage = [self renderQrCodeWithDimension:self.qrCodeButton.frame.size.width * [UIScreen mainScreen].scale];

    switch ([Colors getTheme]) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            qrCodeImage = [qrCodeImage imageWithTint:[UIColor whiteColor]];
            break;
        default:
            qrCodeImage = [qrCodeImage imageWithTint:[UIColor blackColor]];
            break;
    }
    [self.qrCodeButton setImage:qrCodeImage forState:UIControlStateNormal];

    /* linked e-mail */
    if ([MyIdentityStore sharedMyIdentityStore].linkedEmail != nil) {
        if ([MyIdentityStore sharedMyIdentityStore].linkEmailPending) {
            self.linkedEmailLabel.text = NSLocalizedString(@"(pending)", nil);
            [self updatePendingEmailLink];
        } else {
            self.linkedEmailLabel.text = [MyIdentityStore sharedMyIdentityStore].linkedEmail;
        }
    } else {
        self.linkedEmailLabel.text = @" ";
    }

    /* linked mobile number */
    if ([MyIdentityStore sharedMyIdentityStore].linkMobileNoPending) {
        self.linkedMobileNoLabel.text = NSLocalizedString(@"enter_code", nil);
    } else {
        if ([MyIdentityStore sharedMyIdentityStore].linkedMobileNo != nil)
            self.linkedMobileNoLabel.text = [NSString stringWithFormat:@"+%@", [MyIdentityStore sharedMyIdentityStore].linkedMobileNo];
        else
            self.linkedMobileNoLabel.text = @" ";
    }

    [self updateNickname];

    [self updateProfilePicture];

    [self updateColors];

    [self triggerRevocationKeyCheck];

    [self disabledCellsForMDM];
    
    [self updateThreemaSafe];
}

- (void)updateNickname {
    if ([MyIdentityStore sharedMyIdentityStore].pushFromName != nil && [MyIdentityStore sharedMyIdentityStore].pushFromName.length > 0) {
        self.nickNameLabel.text = [MyIdentityStore sharedMyIdentityStore].pushFromName;
        self.nickNameLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"id_completed_nickname", @""), [MyIdentityStore sharedMyIdentityStore].pushFromName];
    } else {
        self.nickNameLabel.text = [MyIdentityStore sharedMyIdentityStore].identity;
        self.nickNameLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"id_completed_nickname", @""), [MyIdentityStore sharedMyIdentityStore].identity];
    }
}

- (void)updateProfilePicture {
    NSData *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture][@"ProfilePicture"];
    if (profilePicture) {
        _imageView.image = [UIImage imageWithData:profilePicture];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.layer.masksToBounds = YES;
        _imageView.layer.cornerRadius = _imageView.bounds.size.width / 2;
    } else {
        _imageView.image = [[AvatarMaker sharedAvatarMaker] unknownPersonImage];
    }

    _imageView.accessibilityLabel = NSLocalizedString(@"my_profilepicture", @"");
}

- (void)updateColors {
    nickNameTitleLabel.textColor = [Colors fontVeryLight];
    nickNameTitleLabel.shadowColor = nil;
    threemaIdTitleLabel.textColor = [Colors fontVeryLight];
    threemaIdTitleLabel.shadowColor = nil;

    nickNameLabel.textColor = [Colors fontNormal];
    nickNameLabel.shadowColor = nil;
    threemaIdLabel.textColor = [Colors fontNormal];
    threemaIdLabel.shadowColor = nil;
    
    UIImage *editImage = [self.editButton.imageView.image imageWithTint:[Colors main]];
    [self.editButton setImage:editImage forState:UIControlStateNormal];
        
    UIImage *shareIdImage = [self.shareIdButton.imageView.image imageWithTint:[Colors main]];
    [self.shareIdButton setImage:shareIdImage forState:UIControlStateNormal];
    
    UIColor *qrBackgroundColor;
    if ([Colors getTheme] == ColorThemeDark || [Colors getTheme] == ColorThemeDarkWork) {
        qrBackgroundColor = [Colors chatBarBackground];
    } else {
        qrBackgroundColor = [Colors fontInverted];
    }
    UIImage *qrBackgroundImage = [self.qrBackgroundImageView.image imageWithTint:qrBackgroundColor];
    qrBackgroundImageView.image = qrBackgroundImage;
    
    UIImage *qrCodeImage = self.qrCodeButton.imageView.image;

    switch ([Colors getTheme]) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            qrCodeImage = [qrCodeImage imageWithTint:[UIColor whiteColor]];
            break;
        default:
            qrCodeImage = [qrCodeImage imageWithTint:[UIColor blackColor]];
            break;
    }
    [self.qrCodeButton setImage:qrCodeImage forState:UIControlStateNormal];
}

- (void)updateThreemaSafe {
    SafeConfigManager *safeConfigManager = [[SafeConfigManager alloc] init];
    SafeStore *safeStore = [[SafeStore alloc] initWithSafeConfigManagerAsObject:safeConfigManager serverApiConnector:[[ServerAPIConnector alloc] init]];
    SafeManager *safeManager = [[SafeManager alloc] initWithSafeConfigManagerAsObject:safeConfigManager safeStore:safeStore safeApiService:[[SafeApiService alloc] init]];
    if ([safeManager isActivated]) {
        self.threemaSafeLabel.text = [BundleUtil localizedStringForKey:@"On"];
    } else {
        self.threemaSafeLabel.text = [BundleUtil localizedStringForKey:@"Off"];
    }
}

- (void)triggerRevocationKeyCheck {
    [_revocationKeyHandler updateLastSetDateForLabel:_revocationLabelDetail];
}

- (void)fullScreenQrCodeTapped:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self hideFullScreenQrViewAnimated:YES];
    }
}

- (void)showFullScreenQrView {
    /* QR code */
    qrRect = _qrCodeButton.frame;
    qrZoomedRect = [_qrCodeButton.superview convertRect:qrRect toView:self.view.superview];

    /* Center in view with margin */
    CGRect contentRect = self.view.superview.frame;
    int maxw = contentRect.size.width - 40;
    int maxh = contentRect.size.height - 40;
    int dim = MIN(maxw, maxh);
    CGRect qrZoomedTargetRect = CGRectMake((contentRect.size.width - dim) / 2, (contentRect.size.height - dim) / 2, dim, dim);

    coverView = [[UIView alloc] initWithFrame:self.view.frame];
    coverView.alpha = 0.0;
    coverView.backgroundColor = [UIColor whiteColor];
    coverView.accessibilityLabel = @"CoverView";
    zoomingQrImageView = [[UIImageView alloc] initWithFrame:qrZoomedRect];
    zoomingQrImageView.image = [self renderQrCodeWithDimension:self.view.frame.size.width * [UIScreen mainScreen].scale];
    zoomingQrImageView.alpha = 0.0;
    zoomingQrImageView.accessibilityLabel = @"Big qr code";
    [coverView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fullScreenQrCodeTapped:)]];
    [self.view.superview addSubview:coverView];
    [self.view.superview addSubview:zoomingQrImageView];

    [UIView animateWithDuration:0.5 animations:^{
        coverView.alpha = 1.0;
        zoomingQrImageView.frame = qrZoomedTargetRect;
        zoomingQrImageView.alpha = 1.0;
    }];
}

- (void)hideFullScreenQrViewAnimated:(BOOL)animated {
    if (coverView == nil)
        return;

    if (animated) {
        [UIView animateWithDuration:0.5 animations:^{
            coverView.alpha = 0.0;
            zoomingQrImageView.frame = qrZoomedRect;
            zoomingQrImageView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [coverView removeFromSuperview];
            [zoomingQrImageView removeFromSuperview];
            coverView = nil;
            zoomingQrImageView = nil;
        }];
    } else {
        [coverView removeFromSuperview];
        [zoomingQrImageView removeFromSuperview];
        coverView = nil;
        zoomingQrImageView = nil;
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self hideFullScreenQrViewAnimated:NO];
}

- (void)createBackup {
    CreatePasswordTrigger *passwordTrigger = [CreatePasswordTrigger createPasswordTriggerOn: self];
    passwordTrigger.passwordCallback = self;
    passwordTrigger.passwordAdditionalText = NSLocalizedString(@"password_description_backup", nil);

    [passwordTrigger presentPasswordUI];
}

- (void)createRevocationKey {
    CreatePasswordTrigger *passwordTrigger = [CreatePasswordTrigger createPasswordTriggerOn: self];
    passwordTrigger.passwordCallback = _revocationKeyHandler;
    passwordTrigger.passwordTitle = NSLocalizedString(@"revocation_password", nil);
    passwordTrigger.passwordAdditionalText = NSLocalizedString(@"revocation_password_description", nil);

    [passwordTrigger presentPasswordUI];
}

- (void)scrollToLinkSection {
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)startSetPublicNickname {
    [self performSegueWithIdentifier:SEGUE_NICKNAME sender:self];
}

- (void)showSafeSetup {
    [self performSegueWithIdentifier:SEGUE_SAFE_SETUP sender:self];
}

- (UIImage*)renderQrCodeWithDimension:(int)dimension {
    MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
    if (!myIdentityStore.isProvisioned) {
        return nil;
    }

    NSMutableString *qrString = [NSMutableString stringWithString:@"3mid:"];
    [qrString appendString:myIdentityStore.identity];
    [qrString appendString:@","];
    [qrString appendString:[NSString stringWithHexData:myIdentityStore.publicKey]];

    return [QRCodeGenerator renderQrCodeString:qrString withDimension:dimension];
}

- (void)disabledCellsForMDM {
    
    // isReadonlyProfile
    self.linkEmailCell.userInteractionEnabled = ![mdmSetup readonlyProfile];
    self.linkEmailCell.textLabel.enabled = ![mdmSetup readonlyProfile];
    self.linkPhoneCell.userInteractionEnabled = ![mdmSetup readonlyProfile];
    self.linkPhoneCell.textLabel.enabled = ![mdmSetup readonlyProfile];
    
    self.idRecoveryCell.userInteractionEnabled = ![mdmSetup readonlyProfile];
    self.idRecoveryCell.textLabel.enabled = ![mdmSetup readonlyProfile];
    self.deleteIdCell.userInteractionEnabled = ![mdmSetup readonlyProfile];
    self.deleteIdCell.textLabel.enabled = ![mdmSetup readonlyProfile];
    self.deleteIdCell.textLabel.text = [BundleUtil localizedStringForKey:@"delete_identity"];

    // disableBackups
    self.backupCell.userInteractionEnabled = !(mdmSetup.disableBackups || mdmSetup.disableIdExport);
    self.backupCell.textLabel.enabled = !(mdmSetup.disableBackups || mdmSetup.disableIdExport);
    
    self.threemaSafeCell.userInteractionEnabled = ![mdmSetup isSafeBackupDisable];
    self.threemaSafeCell.textLabel.enabled = ![mdmSetup isSafeBackupDisable];
}

- (void)tappedHeaderView {
    [self performSegueWithIdentifier:@"EditProfile" sender:nil];
}

- (void)tappedShareThreemaId {
    NSString *threemaShareText = [BundleUtil localizedStringForKey:@"profile_share_id_text"];
    NSString *threemaShareLink = [NSString stringWithFormat:@"%@: %@%@", threemaShareText, THREEMA_ID_SHARE_LINK, [[MyIdentityStore sharedMyIdentityStore] identity]];
    UIActivityViewController *activityViewController = [ActivityUtil activityViewControllerWithActivityItems:@[threemaShareLink] applicationActivities:nil];
    if (SYSTEM_IS_IPAD == YES) {
        activityViewController.popoverPresentationController.sourceRect = _shareIdButton.frame;
        activityViewController.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:activityViewController animated:YES completion:nil];
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 3 && indexPath.row == 0) {
        // handle custom table cells
        [Colors updateTableViewCellBackground:cell];
        [Colors setTextColor:[Colors red] inView:cell.contentView];
    } else {
        [Colors updateTableViewCell:cell];
    }

    if (indexPath.section == 0) {
        self.keyFingerprintLabel.textColor = [Colors fontLight];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0 && ![mdmSetup readonlyProfile] && ![mdmSetup disableBackups] && [mdmSetup disableAddContact]) {
        return NSLocalizedString(@"disabled_by_device_policy", nil);
    }
    else if (section == 1) {
        return NSLocalizedString(![mdmSetup isSafeBackupDisable] ? @"safe_enable_explain_short" : @"disabled_by_device_policy", nil);
    }
    else if (section == 2 && ([mdmSetup readonlyProfile] || [mdmSetup disableBackups] || [mdmSetup disableIdExport])) {
        return NSLocalizedString(@"disabled_by_device_policy", nil);
    }

    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 0.0;
    }
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (indexPath.section == 0 && indexPath.row == 0) {
        /* Link mobile no */
        if ([MyIdentityStore sharedMyIdentityStore].linkMobileNoPending)
            [self performSegueWithIdentifier:@"EnterCode" sender:self];
        else
            [self performSegueWithIdentifier:@"LinkMobileNo" sender:self];
    } else if (indexPath.section == 2 && indexPath.row == 1) {
        [self createBackup];
    } else if (indexPath.section == 2 && indexPath.row == 2) {
        [self createRevocationKey];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [self deleteIdentity:cell];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (IBAction)deleteIdentity:(id)sender {

    if ([KKPasscodeLock sharedLock].isPasscodeRequired) {
        [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"delete_identity_passcode_title", nil) message:NSLocalizedString(@"delete_identity_passcode_message", nil) actionOk:nil];
        return;
    }

    deleteActionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"delete_identity_warning", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [deleteActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete_identity", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"delete_identity", nil) message:NSLocalizedString(@"delete_identity_warning2", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete_identity", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            /* they wanted it that way... */
            [[MyIdentityStore sharedMyIdentityStore] destroy];

            SafeConfigManager *safeConfigManager = [[SafeConfigManager alloc] init];
            [safeConfigManager destroy];

            SafeStore *safeStore = [[SafeStore alloc] initWithSafeConfigManagerAsObject:safeConfigManager serverApiConnector:[[ServerAPIConnector alloc] init]];
            SafeManager *safeManager = [[SafeManager alloc] initWithSafeConfigManagerAsObject:safeConfigManager safeStore:safeStore safeApiService:[[SafeApiService alloc] init]];
            [safeManager setBackupReminder];

            if ([LicenseStore requiresLicenseKey]) {
                // Delete the license when we delete the ID, to give the user a chance to use a new license.
                // The license may have been supplied by MDM, so we load it again.
                [[LicenseStore sharedLicenseStore] deleteLicense];
                [mdmSetup loadLicenseInfo];
                if ([LicenseStore sharedLicenseStore].licenseUsername == nil || [LicenseStore sharedLicenseStore].licensePassword == nil)
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseMissing object:nil];

                [mdmSetup deleteThreemaMdm];
            }

            // Show information about delete all data
            UIStoryboard *storyboard = [AppDelegate getMyIdentityStoryboard];
            UIViewController *deleteIdViewControiller = [storyboard instantiateViewControllerWithIdentifier:@"DeleteIdViewController"];
            deleteIdViewControiller.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:deleteIdViewControiller animated:YES completion:nil];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }]];
    [deleteActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
    }]];

    if ([sender isKindOfClass:[UIView class]]) {
        UIView *senderView = (UIView *)sender;
        deleteActionSheet.popoverPresentationController.sourceRect = senderView.frame;
        deleteActionSheet.popoverPresentationController.sourceView = self.view;
    }

    [self presentViewController:deleteActionSheet animated:YES completion:nil];
}

- (IBAction)scanIdentity:(id)sender {
    if ([mdmSetup disableAddContact]) {
        [UIAlertTemplate showAlertWithOwner:self title:@"" message:NSLocalizedString(@"disabled_by_device_policy", nil) actionOk:nil];
        return;
    }
    ScanIdentityController *scanIdentityController = [[ScanIdentityController alloc] init];
    scanIdentityController.containingViewController = self;
    [scanIdentityController startScan];

    /* a good opportunity to sync contacts - maybe we find the contact
     that the user is about to scan */
    [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES onCompletion:nil onError:nil];
}

#pragma mark - PasswordCallback

-(void)passwordResult:(NSString *)password fromViewController:(UIViewController *)viewController {

    [MBProgressHUD showHUDAddedTo:viewController.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *backupData = [[MyIdentityStore sharedMyIdentityStore] backupIdentityWithPassword:password];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:viewController.view animated:YES];

            UIStoryboard *storyboard = [AppDelegate getMainStoryboard];
            BackupIdentityViewController *idVc = [storyboard instantiateViewControllerWithIdentifier: @"BackupIdentityViewController"];
            idVc.backupData = backupData;

            [viewController.navigationController pushViewController:idVc animated:YES];
        });
    });
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (![LicenseStore requiresLicenseKey]) {
        if ([[self.navigationController navigationBar] frame].size.height < 60.0 && self.navigationItem.titleView != nil) {
            self.navigationItem.titleView = nil;
            self.navigationItem.title = [BundleUtil localizedStringForKey:@"myIdentity"];
        }
        else if ([[self.navigationController navigationBar] frame].size.height >= 59.5 && self.navigationItem.titleView == nil) {
            [BrandingUtils updateTitleLogoOfNavigationItem:self.navigationItem navigationController:self.navigationController];
        }
    }
}

- (void)willDismissModalNavigationController {
    [self updateView];
}

@end
