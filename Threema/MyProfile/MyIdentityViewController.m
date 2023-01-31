//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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
#import <MBProgressHUD/MBProgressHUD.h>
#import "RevocationKeyHandler.h"
#import "QRCodeGenerator.h"
#import "NSString+Hex.h"
#import "AppDelegate.h"
#import "UIImage+ColoredImage.h"
#import "BundleUtil.h"
#import "LicenseStore.h"
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

@interface MyIdentityViewController () <PasswordCallback, UIScrollViewDelegate, ModalNavigationControllerDelegate>

@property RevocationKeyHandler *revocationKeyHandler;
@property LockScreen *lockScreen;

@end

@implementation MyIdentityViewController {
    UIView *coverView;
    UIImageView *zoomingQrImageView;
    CGRect qrRect;
    CGRect qrZoomedRect;
    
    UIBarButtonItem *scanIdentityBarButtonItem;
    
    UIAlertController *deleteActionSheet;
    
    MDMSetup *mdmSetup;
    
    PublicKeyView *publicKeyView;
}

@synthesize nickNameTitleLabel;
@synthesize threemaIdTitleLabel;
@synthesize threemaIdLabel;
@synthesize threemaSafeLabel;
@synthesize nickNameLabel;
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
    
    if ([ScanIdentityController canScan]) {
        scanIdentityBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[BundleUtil imageNamed:@"QRScan"] style:UIBarButtonItemStylePlain target:self action:@selector(scanIdentity:)];
        scanIdentityBarButtonItem.accessibilityLabel = [BundleUtil localizedStringForKey:@"scan_identity"];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateView) name:@"ThreemaIdentityLinkedWithMobileNo" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(incomingSync) name:kNotificationIncomingProfileSynchronization object:nil];
    
    _revocationKeyHandler = [[RevocationKeyHandler alloc] init];
    _lockScreen = [[LockScreen alloc] initWithIsLockScreenController:NO];
    
    [BrandingUtils updateTitleLogoOf:self.navigationItem in:self.navigationController];
    
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
    
    if ([ThreemaAppObjc current] == ThreemaAppOnPrem) {
        _myIdCell.accessoryView = nil;
        _shareIdButton.hidden = true;
    } else {
        UITapGestureRecognizer *shareIdTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedShareThreemaId)];
        [_shareIdButton addGestureRecognizer:shareIdTapRecognizer];
        _shareIdButton.accessibilityTraits = UIAccessibilityTraitNone;
        _shareIdButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"share_id"];
    }
    
    _imageView.accessibilityIgnoresInvertColors = true;
    
    publicKeyView = [[PublicKeyView alloc] initWithIdentity:[MyIdentityStore sharedMyIdentityStore].identity publicKey:[MyIdentityStore sharedMyIdentityStore].publicKey];
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
    [BrandingUtils updateTitleLogoOf:self.navigationItem in:self.navigationController];
    [self updateColors];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self hideFullScreenQrViewAnimated:NO];
    [self updateView];
    
    if (self.presentingViewController != nil) {
        // We are modally presented and have a done button on the right side
        self.navigationItem.leftBarButtonItem = scanIdentityBarButtonItem;
    } else {
        self.navigationItem.rightBarButtonItem = scanIdentityBarButtonItem;
    }
    
    self.navigationItem.largeTitleDisplayMode = [UserSettings sharedUserSettings].largeTitleDisplayMode;
}

- (void)viewWillDisappear:(BOOL)animated {
    [self hideFullScreenQrViewAnimated:NO];
    [publicKeyView close];
    
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

- (void)incomingSync {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateView];
    });
    
    NSString *title = [BundleUtil localizedStringForKey:@"incoming_profile_sync_title"];
    NSString *message = [BundleUtil localizedStringForKey:@"incoming_profile_sync_message"];
    [NotificationBannerHelper newInfoToastWithTitle:title body:message];
}

- (void)updateView {
    threemaIdLabel.text = [MyIdentityStore sharedMyIdentityStore].identity;
    threemaIdLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"my_threema_id"], [MyIdentityStore sharedMyIdentityStore].identity];
    UIImage *qrCodeImage = [self renderQrCodeWithDimension:self.qrCodeButton.frame.size.width * [UIScreen mainScreen].scale];
    qrCodeImage = [qrCodeImage imageWithTint:Colors.qrCodeTint];
    [self.qrCodeButton setImage:qrCodeImage forState:UIControlStateNormal];
    
    /* linked e-mail */
    if ([MyIdentityStore sharedMyIdentityStore].linkedEmail != nil) {
        if ([MyIdentityStore sharedMyIdentityStore].linkEmailPending) {
            self.linkedEmailLabel.text = [BundleUtil localizedStringForKey:@"pending"] ;
            [self updatePendingEmailLink];
        } else {
            self.linkedEmailLabel.text = [MyIdentityStore sharedMyIdentityStore].linkedEmail;
        }
    } else {
        self.linkedEmailLabel.text = @" ";
    }
    
    /* linked mobile number */
    if ([MyIdentityStore sharedMyIdentityStore].linkMobileNoPending) {
        self.linkedMobileNoLabel.text = [BundleUtil localizedStringForKey:@"enter_code"] ;
    } else {
        if ([MyIdentityStore sharedMyIdentityStore].linkedMobileNo != nil)
            self.linkedMobileNoLabel.text = [NSString stringWithFormat:@"+%@", [MyIdentityStore sharedMyIdentityStore].linkedMobileNo];
        else
            self.linkedMobileNoLabel.text = @" ";
    }
    
    _publicKeyLabel.text = [BundleUtil localizedStringForKey:@"public_key"];
    
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
        self.nickNameLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"id_completed_nickname"], [MyIdentityStore sharedMyIdentityStore].pushFromName];
    } else {
        self.nickNameLabel.text = [MyIdentityStore sharedMyIdentityStore].identity;
        self.nickNameLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"id_completed_nickname"], [MyIdentityStore sharedMyIdentityStore].identity];
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
    
    _imageView.accessibilityLabel = [BundleUtil localizedStringForKey:@"my_profilepicture"];
}

- (void)updateColors {
    [super updateColors];
    
    nickNameTitleLabel.textColor = Colors.textLight;
    nickNameTitleLabel.shadowColor = nil;
    threemaIdTitleLabel.textColor = Colors.text;
    threemaIdTitleLabel.shadowColor = nil;
    
    nickNameLabel.shadowColor = nil;
    nickNameLabel.textColor = Colors.text;
    threemaIdLabel.shadowColor = nil;
    threemaIdLabel.textColor = Colors.text;
    
    UIImage *editImage = [self.editButton.imageView.image imageWithTint:Colors.primary];
    [self.editButton setImage:editImage forState:UIControlStateNormal];
    
    UIImage *shareIdImage = [self.shareIdButton.imageView.image imageWithTint:Colors.primary];
    [self.shareIdButton setImage:shareIdImage forState:UIControlStateNormal];
    
    UIImage *qrBackgroundImage = [self.qrBackgroundImageView.image imageWithTint:Colors.backgroundQrCode];
    qrBackgroundImageView.image = qrBackgroundImage;
    
    UIImage *qrCodeImage = self.qrCodeButton.imageView.image;
    qrCodeImage = [qrCodeImage imageWithTint:Colors.qrCodeTint];
    [self.qrCodeButton setImage:qrCodeImage forState:UIControlStateNormal];
    
    [publicKeyView updateColors];
}

- (void)updateThreemaSafe {
    SafeConfigManager *safeConfigManager = [[SafeConfigManager alloc] init];
    SafeStore *safeStore = [[SafeStore alloc] initWithSafeConfigManagerAsObject:safeConfigManager serverApiConnector:[[ServerAPIConnector alloc] init] groupManager: [[GroupManager alloc] init]];
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
    coverView.backgroundColor = [Colors backgroundView];
    coverView.accessibilityLabel = @"CoverView";
    zoomingQrImageView = [[UIImageView alloc] initWithFrame:qrZoomedRect];
    zoomingQrImageView.image = [self renderQrCodeWithDimension:self.view.frame.size.width * [UIScreen mainScreen].scale];
    zoomingQrImageView.alpha = 0.0;
    zoomingQrImageView.backgroundColor = [Colors white];
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
    passwordTrigger.passwordAdditionalText = [BundleUtil localizedStringForKey:@"password_description_backup"] ;
    
    [passwordTrigger presentPasswordUI];
}

- (void)createRevocationKey {
    CreatePasswordTrigger *passwordTrigger = [CreatePasswordTrigger createPasswordTriggerOn: self];
    passwordTrigger.passwordCallback = _revocationKeyHandler;
    passwordTrigger.passwordTitle = [BundleUtil localizedStringForKey:@"revocation_password"] ;
    passwordTrigger.passwordAdditionalText = [BundleUtil localizedStringForKey:@"revocation_password_description"] ;
    
    [passwordTrigger presentPasswordUI];
}

- (void)scrollToLinkSection {
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)startSetPublicNickname {
    if ([self shouldPerformSegueWithIdentifier:SEGUE_NICKNAME sender:self]) {
        [self performSegueWithIdentifier:SEGUE_NICKNAME sender:self];
    }
}

- (void)showSafeSetup {
    if ([self shouldPerformSegueWithIdentifier:SEGUE_SAFE_SETUP sender:self]) {
        [self performSegueWithIdentifier:SEGUE_SAFE_SETUP sender:self];
    }
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
    if ([self shouldPerformSegueWithIdentifier:SEGUE_NICKNAME sender:self]) {
        [self performSegueWithIdentifier:SEGUE_NICKNAME sender:nil];
    }
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // hide ID Revocation Password for OnPrem
    if (section == 3 && [ThreemaAppObjc current] == ThreemaAppOnPrem) {
        return 1;
    }
    
    return [super tableView:tableView numberOfRowsInSection:section];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    
    if (indexPath.section == 4 && indexPath.row == 0) {
        // handle custom table cells
        [Colors setTextColor:Colors.red in:cell.contentView];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0 && ![mdmSetup readonlyProfile] && ![mdmSetup disableBackups] && [mdmSetup disableAddContact]) {
        return [BundleUtil localizedStringForKey:@"disabled_by_device_policy"];
    }
    else if (section == 1) {
        return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"myprofile_link_email_phone_footer"], [ThreemaAppObjc currentName]];
    }
    else if (section == 2) {
        return [BundleUtil localizedStringForKey:![mdmSetup isSafeBackupDisable] ? @"safe_enable_explain_short" : @"disabled_by_device_policy"];
    }
    else if (section == 3 && ([mdmSetup readonlyProfile] || [mdmSetup disableBackups] || [mdmSetup disableIdExport])) {
        return [BundleUtil localizedStringForKey:@"disabled_by_device_policy"];
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
    if (indexPath.section == 0 && indexPath.row == 1) {
        // show public key
        [publicKeyView show];
    }
    else if (indexPath.section == 1 && indexPath.row == 0) {
        /* Link mobile no */
        if ([MyIdentityStore sharedMyIdentityStore].linkMobileNoPending) {
            [self performSegueWithIdentifier:@"EnterCode" sender:self];
        }
        else {
            [self performSegueWithIdentifier:@"LinkMobileNo" sender:self];
        }
    }
    else if (indexPath.section == 3 && indexPath.row == 0) {
        if ([KKPasscodeLock.sharedLock isPasscodeRequired]) {
            [_lockScreen presentLockScreenViewObjCWithViewController:self style:UIModalPresentationAutomatic enteredCorrectly:^{
                [self createBackup];
            } didDismissAfterSuccess:^{
                [self createBackup];
            }];
        }
        else {
            [self createBackup];
        }
    }
    else if (indexPath.section == 3 && indexPath.row == 1) {
        if ([KKPasscodeLock.sharedLock isPasscodeRequired]) {
            [_lockScreen presentLockScreenViewObjCWithViewController:self style:UIModalPresentationAutomatic enteredCorrectly:^{
                [self createRevocationKey];
            } didDismissAfterSuccess:^{
                [self createRevocationKey];
            }];
        }
        else {
            [self createRevocationKey];
        }
    }
    else if (indexPath.section == 4 && indexPath.row == 0) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [self deleteIdentity:cell];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    bool multiDeviceAndNotOnline = ([[ServerConnector sharedServerConnector] isMultiDeviceActivated] == YES) && ([[ServerConnector sharedServerConnector] connectionState] != ConnectionStateLoggedIn);
    if ([identifier isEqualToString:SEGUE_NICKNAME] && multiDeviceAndNotOnline) {
        NSString *title = [BundleUtil localizedStringForKey:@"not_connected_for_edit_profile_title"];
        NSString *message = [BundleUtil localizedStringForKey:@"not_connected_for_edit_profile_message"];
        [UIAlertTemplate showAlertWithOwner:self title:title message:message actionOk:nil];
        return NO;
    }
    
    if ([identifier isEqualToString:SEGUE_SAFE_SETUP] && [KKPasscodeLock.sharedLock isPasscodeRequired]) {
        [_lockScreen presentLockScreenViewObjCWithViewController:self style:UIModalPresentationAutomatic enteredCorrectly:^{
            [self performSegueWithIdentifier:SEGUE_SAFE_SETUP sender:self];
        } didDismissAfterSuccess:nil];
        return NO;
    }
    return YES;
}

- (void)deleteIdentity:(id)sender {
    
    if ([KKPasscodeLock sharedLock].isPasscodeRequired) {
        [UIAlertTemplate showAlertWithOwner:self title:[BundleUtil localizedStringForKey:@"delete_identity_passcode_title"]  message:[BundleUtil localizedStringForKey:@"delete_identity_passcode_message"]  actionOk:nil];
        return;
    }
    
    deleteActionSheet = [UIAlertController alertControllerWithTitle:[BundleUtil localizedStringForKey:@"delete_identity_warning"]  message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [deleteActionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"delete_identity"]  style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction * action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[BundleUtil localizedStringForKey:@"delete_identity"]  message:[BundleUtil localizedStringForKey:@"delete_identity_warning2"] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"]  style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction * action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"delete_identity"]  style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction * action) {
            /* they wanted it that way... */
            [[AppDelegate sharedAppDelegate] eraseApplicationData];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }]];
    [deleteActionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"]  style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction * action) {
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
        [UIAlertTemplate showAlertWithOwner:self title:@"" message:[BundleUtil localizedStringForKey:@"disabled_by_device_policy"]  actionOk:nil];
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
    int navHeight = self.navigationController.navigationBar.frame.size.height;
    BOOL textInNavBar = self.navigationItem.prompt != nil;
    
    if (((navHeight <= BrandingUtils.compactNavBarHeight && !textInNavBar) || (navHeight <= BrandingUtils.compactPromptNavBarHeight && textInNavBar)) && self.navigationItem.titleView != nil) {
        self.navigationItem.titleView = nil;
        self.navigationItem.title = [BundleUtil localizedStringForKey:@"myIdentity"];
    }
    else if (((navHeight > BrandingUtils.compactNavBarHeight && !textInNavBar) || (navHeight > BrandingUtils.compactPromptNavBarHeight && textInNavBar)) && self.navigationItem.titleView == nil) {
        [BrandingUtils updateTitleLogoOf:self.navigationItem in:self.navigationController];
    }
}

- (void)willDismissModalNavigationController {
    [self updateView];
}

@end
