//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2024 Threema GmbH
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

#import "BackupIdentityViewController.h"
#import "QRCodeGenerator.h"
#import "AppDelegate.h"
#import "MyIdentityStore.h"
#import "IdentityBackupStore.h"
#import "UIImage+ColoredImage.h"
#import "AppGroup.h"
#import "ThreemaUtilityObjC.h"
#import "LicenseStore.h"
#import "MDMSetup.h"
#import "ActivityUtil.h"
#import "Threema-Swift.h"

@interface BackupIdentityViewController ()

@property (weak, nonatomic) IBOutlet CopyLabel *identityBackupLabel;
@end

@implementation BackupIdentityViewController {
    UIView *coverView;
    UIImageView *zoomingQrImageView;
    CGRect qrRect;
    CGFloat prevBrightness;
    
    UIImage *qrCodeImage;
    MDMSetup *mdmSetup;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.hidesBackButton = YES;
    
    mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    if (mdmSetup.disableSystemBackups) {
        self.phoneBackupSwitch.on = NO;
        self.phoneBackupSwitch.enabled = NO;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self hideFullScreenQrViewAnimated:NO];
    
    /* Wrap backup data manually for display as iOS text wrap engine doesn't always
       wrap it nicely. Set special attribute on CopyLabel to ensure that copied text
       does not contain line breaks. */
    
    self.identityBackupLabel.textForCopying = self.backupData;
    self.identityBackupLabel.text = [self wrapText:self.backupData withFixedWidth:20];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self hideFullScreenQrViewAnimated:NO];
    
    [super viewWillDisappear:animated];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleTitle3];
    self.identityBackupLabel.font = [UIFont fontWithName:@"Courier" size:fontDescriptor.pointSize];
    
    qrCodeImage = [QRCodeGenerator renderQrCodeString:self.backupData withDimension:self.qrImageView.frame.size.width*2];
    self.qrImageView.image = [qrCodeImage imageWithTint:Colors.qrCodeTint];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appResignActive:(NSNotification*)notification {
    [self hideFullScreenQrViewAnimated:NO];
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

- (IBAction)doneAction:(id)sender {
    if (self.phoneBackupSwitch.on)
        [IdentityBackupStore saveIdentityBackup:self.backupData];
    else
        [IdentityBackupStore deleteIdentityBackup];
    
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)actionAction:(id)sender {
    UIActivityViewController *activityViewController = [ActivityUtil activityViewControllerWithActivityItems:@[self] applicationActivities:@[]];
    
    if (SYSTEM_IS_IPAD == YES) {
        CGRect rect = [self.view convertRect:self.view.frame fromView:self.view.superview];
        activityViewController.popoverPresentationController.sourceRect = rect;
        activityViewController.popoverPresentationController.sourceView = self.view;
    }
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    [defaults setDouble:[ThreemaUtilityObjC systemUptime] forKey:@"UIActivityViewControllerOpenTime"];
    [defaults synchronize];
    
    [activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults removeObjectForKey:@"UIActivityViewControllerOpenTime"];
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (IBAction)phoneBackupSwitchChanged:(id)sender {
    [self.tableView reloadData];
}

- (void)fullScreenQrCodeTapped:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self hideFullScreenQrViewAnimated:YES];
    }
}

- (void)showFullScreenQrView {
    /* QR code */
    qrRect = [self.qrImageView.superview convertRect:self.qrImageView.frame toView:self.view.superview];
    
    /* Center in view with margin */
    CGRect contentRect = self.view.superview.frame;
    int maxw = contentRect.size.width - 40;
    int maxh = contentRect.size.height - 40;
    int dim = MIN(maxw, maxh);
    CGRect qrTargetRect = CGRectMake((contentRect.size.width - dim) / 2, (contentRect.size.height - dim) / 2, dim, dim);
    
    coverView = [[UIView alloc] initWithFrame:self.view.frame];
    coverView.alpha = 0.0;
    coverView.backgroundColor = [UIColor whiteColor];
    zoomingQrImageView = [[UIImageView alloc] initWithFrame:qrRect];
    zoomingQrImageView.image = qrCodeImage;
    zoomingQrImageView.alpha = 0.75;
    [coverView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fullScreenQrCodeTapped:)]];
    [self.view.superview addSubview:coverView];
    [self.view.superview addSubview:zoomingQrImageView];
    self.qrImageView.hidden = YES;
    
    [UIView animateWithDuration:0.5 animations:^{
        coverView.alpha = 1.0;
        zoomingQrImageView.frame = qrTargetRect;
        zoomingQrImageView.alpha = 1.0;
    }];
    
    prevBrightness = [UIScreen mainScreen].brightness;
    [UIScreen mainScreen].brightness = 1.0;
}

- (void)hideFullScreenQrViewAnimated:(BOOL)animated {
    if (coverView == nil)
        return;
    
    if (animated) {
        [UIView animateWithDuration:0.5 animations:^{
            coverView.alpha = 0.0;
            zoomingQrImageView.frame = qrRect;
            zoomingQrImageView.alpha = 0.75;
        } completion:^(BOOL finished) {
            self.qrImageView.hidden = NO;
            [coverView removeFromSuperview];
            [zoomingQrImageView removeFromSuperview];
            coverView = nil;
            zoomingQrImageView = nil;
        }];
    } else {
        self.qrImageView.hidden = NO;
        [coverView removeFromSuperview];
        [zoomingQrImageView removeFromSuperview];
        coverView = nil;
        zoomingQrImageView = nil;
    }
    
    [UIScreen mainScreen].brightness = prevBrightness;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self hideFullScreenQrViewAnimated:NO];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (NSString*)wrapText:(NSString*)text withFixedWidth:(NSUInteger)width {
    NSMutableString *wrappedText = [NSMutableString string];
    
    NSUInteger offset = 0;
    while (offset < text.length) {
        if (wrappedText.length > 0)
            [wrappedText appendString:@"\n"];
        
        NSUInteger rangeLen = MIN(text.length - offset, width);
        [wrappedText appendString:[text substringWithRange:NSMakeRange(offset, rangeLen)]];
        offset += rangeLen;
    }
    
    return wrappedText;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1 && indexPath.row == 1) {
        [self showFullScreenQrView];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        if (mdmSetup.disableSystemBackups) {
            return [BundleUtil localizedStringForKey:@"disabled_by_device_policy"];
        } else {
            if (self.phoneBackupSwitch.on) {
                return [BundleUtil localizedStringForKey:@"backup_include"];
            } else {
                return [BundleUtil localizedStringForKey:@"backup_exclude"];
            }
        }
    } else if (section == 1) {
        return [BundleUtil localizedStringForKey:@"backup_footer"];
    }
    
    return nil;
}

#pragma mark - UIActivityItemSource

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController {
    return [self activityViewController:activityViewController itemForActivityType:nil];
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(UIActivityType)activityType {
    return self.backupData;
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(UIActivityType)activityType {
    NSString *subject = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"backup_mail_subject"], [MyIdentityStore sharedMyIdentityStore].identity];
    return subject;
}

@end
