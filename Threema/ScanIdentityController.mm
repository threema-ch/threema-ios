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

#import "ScanIdentityController.h"
#import "AppDelegate.h"
#import "NewScannedContactViewController.h"
#import "MyIdentityStore.h"
#import "NSString+Hex.h"
#import "NaClCrypto.h"
#import "ContactStore.h"
#import "Contact.h"
#import "IdentityVerifiedViewController.h"
#import "UserSettings.h"
#import "ServerAPIConnector.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "QRScannerViewController.h"
#import "StatusNavigationBar.h"
#import "PortraitNavigationController.h"
#import "EntityManager.h"
#import "BundleUtil.h"
#import "URLHandler.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

#define THREEMA_ID_SHARE_LINK @"https://threema.id/"

@implementation ScanIdentityController {
    NSString *scannedIdentity;
    NSData *scannedPublicKey;
    Contact *existingContact;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.popupScanResults = YES;
    }
    return self;
}

+ (BOOL)canScan {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSArray *mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
        return [mediaTypes containsObject:(NSString *)kUTTypeMovie];
    }
    return NO;
}

static void soundCompletionCallback(SystemSoundID soundId, void *arg) {
    
    AudioServicesRemoveSystemSoundCompletion(soundId);
    AudioServicesDisposeSystemSoundID(soundId);
}

- (void)playSuccessSound {
    if (![UserSettings sharedUserSettings].inAppSounds)
        return;
    
    SystemSoundID scanSuccessSound;
    NSString *sendPath = [BundleUtil pathForResource:@"scan_success" ofType:@"caf"];
    CFURLRef baseURL = (__bridge CFURLRef)[NSURL fileURLWithPath:sendPath];
    AudioServicesCreateSystemSoundID(baseURL, &scanSuccessSound);
    AudioServicesAddSystemSoundCompletion(scanSuccessSound, NULL, NULL, soundCompletionCallback, NULL);
    AudioServicesPlaySystemSound(scanSuccessSound);
}

- (void)startScan {
    [MBProgressHUD showHUDAddedTo:self.containingViewController.view animated:YES];
    
    QRScannerViewController *qrController = [[QRScannerViewController alloc] init];
    
    qrController.delegate = self;
    qrController.title = NSLocalizedString(@"scan_identity", nil);
    
    UINavigationController *nav = [[PortraitNavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
    [nav pushViewController:qrController animated:NO];
    
    nav.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self.containingViewController presentViewController:nav animated:YES completion:nil];
}

#pragma mark - QRScannerViewControllerDelegate

- (void)qrScannerViewController:(QRScannerViewController *)controller didScanResult:(NSString *)result {
    DDLogVerbose(@"Scanned data: %@", result);
    [MBProgressHUD hideHUDForView:self.containingViewController.view animated:NO];
    [self processScanResult:result controller:controller];
}

- (void)qrScannerViewControllerDidCancel:(QRScannerViewController *)controller {
    DDLogVerbose(@"Scan cancelled");
    [MBProgressHUD hideHUDForView:self.containingViewController.view animated:NO];
    [self.containingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Scan utility functions

- (void)processScanResult:(NSString*)result controller:(QRScannerViewController *)controller {

    /* Is this another Threema identity? */
    NSString *_scannedIdentity;
    NSData *_scannedPublicKey;
    NSDate *_scannedExpirationDate;
    if ([self parseScannedContact:result identity:&_scannedIdentity publicKey:&_scannedPublicKey expirationDate:&_scannedExpirationDate]) {
        if ([UserSettings sharedUserSettings].inAppVibrate)
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
        scannedIdentity = _scannedIdentity;
        scannedPublicKey = _scannedPublicKey;
        
        if (self.expectedIdentity != nil && ![self.expectedIdentity isEqualToString:scannedIdentity]) {
            [self.containingViewController dismissViewControllerAnimated:YES completion:^{
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"scanned_identity_mismatch_title", nil) message:NSLocalizedString(@"scanned_identity_mismatch_message", nil) actionOk:^(UIAlertAction * _Nonnull) {
                    [controller stopRunning];
                }];
            }];
            return;
        }
        
        if ([scannedIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
            [self.containingViewController dismissViewControllerAnimated:YES completion:^{
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"scanned_own_identity_title", nil) message:@"" actionOk:^(UIAlertAction * _Nonnull) {
                    [controller stopRunning];
                }];
            }];
            return;
        }
        
        if (_scannedExpirationDate != nil && [_scannedExpirationDate compare:[NSDate date]] == NSOrderedAscending) {
            [self.containingViewController dismissViewControllerAnimated:YES completion:^{
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"scan_code_expired_title", nil) message:NSLocalizedString(@"scan_code_expired_message", nil) actionOk:^(UIAlertAction * _Nonnull) {
                    [controller stopRunning];
                }];
            }];
            return;
        }
        
        /* Do we already have a contact record for this identity? */
        EntityManager *entityManager = [[EntityManager alloc] init];
        existingContact = [entityManager.entityFetcher contactForId:scannedIdentity];
        
        if (existingContact != nil) {
            /* Check that the public key matches */
            if (![existingContact.publicKey isEqualToData:scannedPublicKey]) {
                /* Not good */
                DDLogError(@"Scanned public key doesn't match for existing identity %@!", scannedIdentity);
                
                [self.containingViewController dismissViewControllerAnimated:YES completion:^{
                    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"public_key_mismatch_title", nil) message:NSLocalizedString(@"public_key_mismatch_message", nil) actionOk:nil];
                }];
            } else {
                [self playSuccessSound];
                [[ContactStore sharedContactStore] upgradeContact:existingContact toVerificationLevel:kVerificationLevelFullyVerified];
                [self.containingViewController dismissViewControllerAnimated:YES completion:^{
                    if (self.popupScanResults) {
                        UIStoryboard *storyboard = [AppDelegate getMainStoryboard];
                        UINavigationController *idNavVc = [storyboard instantiateViewControllerWithIdentifier:@"VerifyScannedContact"];
                        IdentityVerifiedViewController *idVc = [idNavVc.viewControllers objectAtIndex:0];
                        idVc.contact = existingContact;
                        [self.containingViewController presentViewController:idNavVc animated:YES completion:nil];
                    }
                }];
            }
        } else {
            [self playSuccessSound];
            
            [self.containingViewController dismissViewControllerAnimated:YES completion:^{
                
                /* don't blindly trust the public key that we scanned - get the key for this
                 identity from the server and compare */
                [MBProgressHUD showHUDAddedTo:self.containingViewController.view animated:YES];
                
                ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
                [conn fetchIdentityInfo:scannedIdentity onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
                    [MBProgressHUD hideHUDForView:self.containingViewController.view animated:YES];
                    
                    if (![scannedPublicKey isEqualToData:publicKey]) {
                        DDLogError(@"Scanned public key doesn't match key returned by server for %@!", scannedIdentity);
                        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"public_key_server_mismatch_title", nil) message:NSLocalizedString(@"public_key_server_mismatch_message", nil) actionOk:nil];
                    } else {
                        UIStoryboard *storyboard = [AppDelegate getMainStoryboard];
                        UINavigationController *newNavVc = [storyboard instantiateViewControllerWithIdentifier:@"NewScannedContact"];
                        NewScannedContactViewController *newVc = [newNavVc.viewControllers objectAtIndex:0];
                        newVc.identity = scannedIdentity;
                        newVc.publicKey = scannedPublicKey;
                        newVc.verificationLevel = kVerificationLevelFullyVerified;
                        newVc.state = state;
                        newVc.type = type;
                        newVc.featureMask = featureMask;
                        
                        [self.containingViewController presentViewController:newNavVc animated:YES completion:nil];
                    }
                } onError:^(NSError *error) {
                    [MBProgressHUD hideHUDForView:self.containingViewController.view animated:YES];
                    
                    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
                }];
            }];
        }
    }
    else if ([result hasPrefix:THREEMA_ID_SHARE_LINK]) {
        [self playSuccessSound];
        
        [self.containingViewController dismissViewControllerAnimated:YES completion:^{
            NSURL *shareLink = [NSURL URLWithString:result];
            NSString *targetId = [[shareLink.path substringFromIndex:1] uppercaseString];
            if (targetId.length != kIdentityLen) {
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"identity_not_found_title", nil) message:NSLocalizedString(@"identity_not_found_message", nil) actionOk:^(UIAlertAction * _Nonnull) {
                    [controller stopRunning];
                }];
                return;
            } 
            [URLHandler handleThreemaDotIdUrl:[NSURL URLWithString:result] hideAppChooser:true];
        }];
    }
    else {
        NSData *qrCodeWithData = [[NSData alloc] initWithBase64EncodedString:result options:nil];
        if (qrCodeWithData != nil) {
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"webClient_scan_error_title", nil) message:NSLocalizedString(@"webClient_scan_error_message", nil) actionOk:^(UIAlertAction * _Nonnull) {
                [controller startRunning];
            }];
        }
        DDLogVerbose(@"2D code data not recognized");
    }
}

- (int)parseScannedContact:(NSString*)scanData identity:(NSString**)identity publicKey:(NSData**)publicKey expirationDate:(NSDate**)expirationDate {
    
    NSArray *components = [scanData componentsSeparatedByString:@":"];
    if (components.count != 2) {
        DDLogVerbose(@"Wrong number of components: %lu", (unsigned long)components.count);
        return 0;
    }
    
    if (![components[0] isEqualToString:@"3mid"]) {
        DDLogVerbose(@"Wrong prefix %@", components[0]);
        return 0;
    }
    
    NSArray *components2 = [components[1] componentsSeparatedByString:@","];
    if (components2.count < 2) {
        DDLogVerbose(@"Wrong number of components2: %lu", (unsigned long)components2.count);
        return 0;
    }
    *identity = components2[0];
    *publicKey = [components2[1] decodeHex];
    
    if (*publicKey == nil || (*publicKey).length != kNaClCryptoPubKeySize) {
        DDLogVerbose(@"Invalid public key length");
        return 0;
    }
    
    if (components2.count >= 3)
        *expirationDate = [NSDate dateWithTimeIntervalSince1970:[components2[2] doubleValue]];
    else
        *expirationDate = nil;
    
    return 1;
}

@end
