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

#import <MobileCoreServices/UTCoreTypes.h>

#import "ScanIdentityController.h"
#import "AppDelegate.h"
#import "MyIdentityStore.h"
#import "NSString+Hex.h"
#import "NaClCrypto.h"
#import "ContactStore.h"
#import "ContactEntity.h"
#import "UserSettings.h"
#import "ServerAPIConnector.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "QRScannerViewController.h"
#import "PortraitNavigationController.h"
#import "EntityFetcher.h"
#import "BundleUtil.h"
#import "URLHandler.h"
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

static void soundCompletionCallback(SystemSoundID soundId, __unused void* __nullable clientDat) {
    AudioServicesRemoveSystemSoundCompletion(soundId);
    AudioServicesDisposeSystemSoundID(soundId);
}

@implementation ScanIdentityController {
    NSString *scannedIdentity;
    NSData *scannedPublicKey;
    ContactEntity *existingContact;
}

+ (BOOL)canScan {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSArray *mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
        return [mediaTypes containsObject:(NSString *)kUTTypeMovie];
    }
    return NO;
}

- (void)playSuccessSound {
    if (![UserSettings sharedUserSettings].inAppSounds) {
        return;
    }
    
    SystemSoundID scanSuccessSound;
    NSString *sendPath = [BundleUtil pathForResource:@"scan_success" ofType:@"caf"];
    if (sendPath == nil) {
        return;
    }
    CFURLRef baseURL = (__bridge CFURLRef)[NSURL fileURLWithPath:sendPath];
    AudioServicesCreateSystemSoundID(baseURL, &scanSuccessSound);
    AudioServicesAddSystemSoundCompletion(scanSuccessSound, NULL, NULL, soundCompletionCallback, NULL);
    AudioServicesPlaySystemSound(scanSuccessSound);
}

- (void)startScan {
    if (self.containingViewController.view != nil) {
        [MBProgressHUD showHUDAddedTo:self.containingViewController.view animated:YES];
    }
    
    QRScannerViewController *qrController = [[QRScannerViewController alloc] init];
    
    qrController.delegate = self;
    qrController.title = [BundleUtil localizedStringForKey:@"scan_identity"];
    qrController.navigationItem.scrollEdgeAppearance = [Colors defaultNavigationBarAppearance];

    UINavigationController *nav = [[UINavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
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

- (void)qrScannerViewController:(QRScannerViewController *)controller didCancelAndWillDismissItself:(BOOL)willDismissItself {
    DDLogVerbose(@"Scan cancelled");
    [MBProgressHUD hideHUDForView:self.containingViewController.view animated:NO];
    
    if (self.completion) {
        self.completion(false);
    }
    
    if (!willDismissItself) {
        [self.containingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Scan utility functions

- (void)processScanResult:(NSString*)result controller:(QRScannerViewController *)controller {

    /* Is this another Threema identity? */
    NSString *_scannedIdentity;
    NSData *_scannedPublicKey;
    NSDate *_scannedExpirationDate;
    if ([self parseScannedContact:result identity:&_scannedIdentity publicKey:&_scannedPublicKey expirationDate:&_scannedExpirationDate]) {
        if ([UserSettings sharedUserSettings].inAppVibrate) {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
        }
        scannedIdentity = _scannedIdentity;
        scannedPublicKey = _scannedPublicKey;
        
        if (self.expectedIdentity != nil && ![self.expectedIdentity isEqualToString:scannedIdentity]) {
            [self dismissContainingViewControllerFullyVerified:NO completion:^{
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"scanned_identity_mismatch_title"] message:[BundleUtil localizedStringForKey:@"scanned_identity_mismatch_message"] actionOk:^(__unused UIAlertAction * _Nonnull okAction) {
                    [controller stopRunning];
                }];
            }];
            return;
        }
        
        if ([scannedIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
            [self dismissContainingViewControllerFullyVerified:NO completion:^{
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"scanned_own_identity_title"] message:@"" actionOk:^(__unused UIAlertAction * _Nonnull okAction) {
                    [controller stopRunning];
                }];
            }];
            return;
        }
        
        if (_scannedExpirationDate != nil && [_scannedExpirationDate compare:[NSDate date]] == NSOrderedAscending) {
            [self dismissContainingViewControllerFullyVerified:NO completion:^{
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"scan_code_expired_title"] message:[BundleUtil localizedStringForKey:@"scan_code_expired_message"] actionOk:^(__unused UIAlertAction * _Nonnull okAction) {
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
                
                [self dismissContainingViewControllerFullyVerified:NO completion:^{
                    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"public_key_mismatch_title"] message:[BundleUtil localizedStringForKey:@"public_key_mismatch_message"] actionOk:nil];
                }];
            } else {
                [self playSuccessSound];
                [[ContactStore sharedContactStore] upgradeContact:existingContact toVerificationLevel:kVerificationLevelFullyVerified];
                [self dismissContainingViewControllerFullyVerified:YES completion:^{
                    [[NotificationPresenterWrapper shared] presentIDVerified];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowContact object:nil userInfo:@{kKeyContact: existingContact}];
                }];
            }
        } else {
            [self playSuccessSound];
            
            [self.containingViewController dismissViewControllerAnimated:YES completion:^{
                
                if (self.containingViewController.view != nil) {
                    [MBProgressHUD showHUDAddedTo:self.containingViewController.view animated:YES];
                }
                
                /* Don't blindly trust the public key that we scanned - get the key for this
                 identity from the server and compare */
                ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
                [conn fetchIdentityInfo:scannedIdentity onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
                    [MBProgressHUD hideHUDForView:self.containingViewController.view animated:YES];
                    
                    if (![scannedPublicKey isEqualToData:publicKey]) {
                        DDLogError(@"Scanned public key doesn't match key returned by server for %@!", scannedIdentity);
                        
                        if (self.completion) {
                            self.completion(NO);
                        }
                        
                        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"public_key_server_mismatch_title"] message:[BundleUtil localizedStringForKey:@"public_key_server_mismatch_message"] actionOk:nil];
                    } else {
                        [[ContactStore sharedContactStore] addContactWithIdentity:scannedIdentity publicKey:publicKey cnContactId:nil verificationLevel:kVerificationLevelFullyVerified state:state type:type featureMask:featureMask acquaintanceLevel:ContactAcquaintanceLevelDirect alerts:YES onCompletion:^(ContactEntity * _Nullable contact) {

                            if (contact == nil) {
                                DDLogError(@"Unable to store scanned contact: %@", scannedIdentity);

                                if (self.completion) {
                                    self.completion(NO);
                                }

                                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"scan_id_add_contact_failed_title"] message:[BundleUtil localizedStringForKey:@"scan_id_add_contact_failed_message"] actionOk:nil];
                                return;
                            }

                            if (self.completion) {
                                self.completion(YES);
                            }

                            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowContact object:nil userInfo:@{kKeyContact: contact}];
                        }];
                    }
                } onError:^(NSError *error) {
                    [MBProgressHUD hideHUDForView:self.containingViewController.view animated:YES];
                    
                    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == 404) {
                        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"identity_not_found_title"] message: [BundleUtil localizedStringForKey:@"identity_not_found_message"] actionOk:nil];
                    } else {
                        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
                    }
                }];
            }];
        }
    }
    else if ([result hasPrefix:THREEMA_ID_SHARE_LINK]) {
        [self playSuccessSound];
        
        [self dismissContainingViewControllerFullyVerified:NO completion:^{
            NSURL *shareLink = [NSURL URLWithString:result];
            NSString *targetId = [[shareLink.path substringFromIndex:1] uppercaseString];
            if (targetId.length != kIdentityLen) {
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"identity_not_found_title"] message:[BundleUtil localizedStringForKey:@"identity_not_found_message"] actionOk:^(__unused UIAlertAction * _Nonnull okAction) {
                    [controller stopRunning];
                }];
                return;
            }
            [URLHandler handleThreemaDotIdUrl:[NSURL URLWithString:result] hideAppChooser:true];
        }];
    }
    else {
        [controller stopRunning];
        NSData *qrCodeWithData = [[NSData alloc] initWithBase64EncodedString:result options:0];
        if (qrCodeWithData != nil) {
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"webClient_scan_error_title"] message:[BundleUtil localizedStringForKey:@"webClient_scan_error_message"] actionOk:^(__unused UIAlertAction * _Nonnull okAction) {
                [controller startRunning];
            }];
        }
        else {
            NSString *message = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"scanned_non_threema_id_message"], [ThreemaAppObjc appName]];
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"scanned_non_threema_id_title"] message:message actionOk:^(__unused UIAlertAction * _Nonnull okAction) {
                [controller startRunning];
                return;
            }];
        }
        DDLogVerbose(@"2D code data not recognized");
    }
}

- (void)dismissContainingViewControllerFullyVerified:(BOOL)fullyVerified completion:(void (^ __nullable)(void))completion {
    if (self.completion) {
        self.completion(fullyVerified);
    }
    
    [self.containingViewController dismissViewControllerAnimated:YES completion:completion];
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
