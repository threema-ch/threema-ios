//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import <QuartzCore/QuartzCore.h>
#import "ChatSettingsViewController.h"
#import "UserSettings.h"
#import "UIImage+Resize.h"
#import "AppDelegate.h"
#import "ModalPresenter.h"
#import "Colors.h"
#import "LicenseStore.h"
#import <Photos/Photos.h>
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"

@interface ChatSettingsViewController ()

@end

@implementation ChatSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [[UserSettings sharedUserSettings] checkWallpaper];
    
    self.wallpaperImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.wallpaperImageView.layer.shadowOffset = CGSizeMake(1, 1);
    self.wallpaperImageView.layer.shadowOpacity = 0.25;
    self.wallpaperImageView.layer.shadowRadius = 5.0;
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateView];
}

- (void)updateView {
    UIImage *wallpaper = [UserSettings sharedUserSettings].wallpaper;
    [self.wallpaperImageView.layer setBorderColor: [[Colors hairline] CGColor]];
    [self.wallpaperImageView.layer setBorderWidth: 2.0];

    if (wallpaper != nil) {
        self.wallpaperImageView.image = wallpaper;
        self.wallpaperImageView.backgroundColor = nil;
    }
    else {
        self.wallpaperImageView.image = nil;
        [self.wallpaperImageView setBackgroundColor:[Colors backgroundChat]];
        
        if ([LicenseStore requiresLicenseKey] == false) {
            UIImage *chatBackground = [BundleUtil imageNamed:@"ChatBackground"];
            chatBackground = [chatBackground imageWithTint:[Colors chatBackgroundLines]];
            self.wallpaperImageView.backgroundColor = [UIColor colorWithPatternImage:chatBackground];
        }
    }
    
    if ([UserSettings sharedUserSettings].useDynamicFontSize) {
        self.fontSizeLabel.text = NSLocalizedString(@"use_dynamic_font_size", nil);
    } else {
        self.fontSizeLabel.text = [NSString stringWithFormat:@"%.0f %@", [UserSettings sharedUserSettings].chatFontSize,
                                   NSLocalizedString(@"font_point", nil)];
    }
    
    self.biggerEmojiLabel.text = [BundleUtil localizedStringForKey:@"bigger_single_emojis"];
    
    self.showReceivedTimestampSwitch.on = [UserSettings sharedUserSettings].showReceivedTimestamps;
    self.returnToSendSwitch.on = [UserSettings sharedUserSettings].returnToSend;
    self.biggerEmojiSwitch.on = ![UserSettings sharedUserSettings].disableBigEmojis;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        return 178.0;
    }
    
    return UITableViewAutomaticDimension;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        return 178.0;
    }
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    __block UIImagePickerController *picker = nil;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            __block CGRect rect;
            if (![[NSThread currentThread] isMainThread]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    rect = [tableView rectForRowAtIndexPath:indexPath];
                });
            } else {
                rect = [tableView rectForRowAtIndexPath:indexPath];
            }
            
            if (@available(iOS 11, *)) {
                picker = [[UIImagePickerController alloc] init];
                picker.delegate = self;
                [ModalPresenter present:picker on:self fromRect:rect inView:self.view];
            } else {
                [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                    switch (status) {
                        case PHAuthorizationStatusDenied:
                        case PHAuthorizationStatusRestricted:
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:nil message:[BundleUtil localizedStringForKey:@"save_photo_failed_message"] actionOk:nil];
                            });
                            break;
                        case PHAuthorizationStatusNotDetermined:
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:nil message:[BundleUtil localizedStringForKey:@"save_photo_failed_message"] actionOk:nil];
                            });
                            break;
                        case PHAuthorizationStatusAuthorized:
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                picker = [[UIImagePickerController alloc] init];
                                picker.delegate = self;
                                [ModalPresenter present:picker on:self fromRect:rect inView:self.view];
                            });
                            break;
                    }
                }];
            }
        } else if (indexPath.row == 1) {
            /* reset */
            [UserSettings sharedUserSettings].wallpaper = nil;
            [self updateView];
        }
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - image picker delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    UIImage *pickedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    /* resize to fit screen (for better performance) */
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    screenSize.height *= [UIScreen mainScreen].scale;
    screenSize.width *= [UIScreen mainScreen].scale;
    UIImage *scaled = [pickedImage resizedImageWithContentMode:UIViewContentModeScaleAspectFill bounds:screenSize interpolationQuality:kCGInterpolationHigh];
    [UserSettings sharedUserSettings].wallpaper = scaled;
    
    [self handlePickerFinished];
    [self updateView];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self handlePickerFinished];
}

- (void)handlePickerFinished {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    [ModalPresenter dismissPresentedControllerOn:self animated:YES];
}

- (IBAction)showReceivedTimestampChanged:(id)sender {
    [UserSettings sharedUserSettings].showReceivedTimestamps = self.showReceivedTimestampSwitch.on;
}

- (IBAction)returnToSendChanged:(id)sender {
    [UserSettings sharedUserSettings].returnToSend = self.returnToSendSwitch.on;
}

- (IBAction)biggerEmojiChanged:(id)sender {
    [UserSettings sharedUserSettings].disableBigEmojis = !self.biggerEmojiSwitch.on;
}

@end
