//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2024 Threema GmbH
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

#include <CommonCrypto/CommonCrypto.h>

#import "URLHandler.h"
#import "ServerAPIConnector.h"
#import "AppDelegate.h"
#import "MyIdentityStore.h"
#import "UIDefines.h"
#import "ContactStore.h"
#import "ShareController.h"
#import "NSString+Hex.h"
#import "ScanIdentityController.h"
#import "LicenseStore.h"
#import "BundleUtil.h"
#import "MDMSetup.h"
#import "WorkDataFetcher.h"
#import "Threema-Swift.h"
#import "SplashViewController.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation URLHandler

+ (BOOL)handleURL:(NSURL *)url {
    
    if ([url.scheme hasPrefix:@"threema"]) {
        
        if ([url.host isEqualToString:@"link_mobileno"]) {
            NSString *code = [url.query stringByReplacingOccurrencesOfString:@"code=" withString:@""];
            DDLogVerbose(@"code: %@", code);
            
            ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
            [conn linkMobileNoWithStore:[MyIdentityStore sharedMyIdentityStore] code:code onCompletion:^(BOOL linked) {
                UITabBarController *mainTabBar = [AppDelegate getMainTabBarController];
                mainTabBar.selectedIndex = kMyIdentityTabBarIndex;
                
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"mobileno_linked_title"] message:[BundleUtil localizedStringForKey:@"mobileno_linked_message"] actionOk:nil];
            } onError:^(NSError *error) {
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
            }];
            
            return YES;
        } else if ([url.host isEqualToString:@"restore"]) {
            /* only react to restore URLs if we're currently presenting the generate key view controller */
            AppDelegate *appDelegate = [AppDelegate sharedAppDelegate];
            if ([appDelegate isPresentingKeyGeneration]) {
                appDelegate.urlRestoreData = [url.query stringByReplacingOccurrencesOfString:@"backup=" withString:@""];
                [appDelegate presentIDBackupRestore];
            }
                        
            return YES;
        } else if ([url.host isEqualToString:@"add"] || [url.host isEqualToString:@"compose"]) {
            NSDictionary *query = [url.query dictionaryFromQueryComponents];
            
            NSString *targetId = [[query objectForKey:@"id"][0] uppercaseString];
            
            if (targetId.length == kIdentityLen) {
                [URLHandler handleAddIdentity:targetId compose:[url.host isEqualToString:@"compose"] query:query];
            } else {
                /* share with unspecified contact */
                if ([url.host isEqualToString:@"compose"]) {
                    ShareController *shareController = [[ShareController alloc] init];
                    shareController.text = [query objectForKey:@"text"][0];
                    if ([[query objectForKey:@"image"][0] isEqualToString:@"pasteboard"])
                        shareController.image = [self decryptPasteboardImageWithKey:[query objectForKey:@"key"][0]];
                    [shareController startShare];
                }
            }
            
            return YES;
        } else if ([url.host isEqualToString:@"license"]) {
            [self handleLicenseUrl:url];
            return YES;
        }
    } else if ([url.scheme isEqualToString:@"file"]) {
        ShareController *shareController = [[ShareController alloc] init];
        shareController.url = url;
        [shareController startShare];
        return YES;
    } else if (([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) && [[url.host lowercaseString] isEqualToString:@"threema.id"]) {
        [self handleThreemaDotIdUrl:url hideAppChooser:false];
        return YES;
    }
    if (([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) &&
        [[url.host lowercaseString] isEqualToString:@"threema.ch"]) {
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            return YES;
        }
    }
    return NO;
}

+ (void)handleLicenseUrl:(NSURL *)url {
    NSDictionary *query = [url.query dictionaryFromQueryComponents];
    
    LicenseStore *licenseStore = [LicenseStore sharedLicenseStore];
    if ([licenseStore isValid] == NO) {
        [licenseStore performLicenseCheckWithCompletion:^(BOOL success) {
            if (success) {
                if ([LicenseStore requiresLicenseKey] == true) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"already_licensed"] message:@"" actionOk:nil];
                    });
                }
            } else {
                NSString *username = [query objectForKey:@"username"][0];
                NSString *password = [query objectForKey:@"password"][0];
                NSString *server = [query objectForKey:@"server"][0];
                
                // show license screen if
                if (username == nil || password == nil || (server == nil && ThreemaAppObjc.current == ThreemaAppOnPrem)) {
                    [licenseStore setLicenseUsername:username];
                    [licenseStore setLicensePassword:password];
                    if (ThreemaAppObjc.current == ThreemaAppOnPrem) {
                        [licenseStore setOnPremConfigUrl:server];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseMissing object:nil];
                    });
                } else {
                    [licenseStore setLicenseUsername:username];
                    [licenseStore setLicensePassword:password];
                    if (ThreemaAppObjc.current == ThreemaAppOnPrem) {
                        [licenseStore setOnPremConfigUrl:server];
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[AppDelegate sharedAppDelegate] isPresentingEnterLicense]) {
                            UIViewController *currentVC = [AppDelegate sharedAppDelegate].window.rootViewController;
                            if ([currentVC isKindOfClass:[SplashViewController class]] == NO) {
                                // Check license, do Work API fetch and connect if is disconnected
                                [self performLicenseCheckWithLicenseStore:licenseStore];
                            }
                            else {
                                // Setup is running, just close enter license view
                                // License check and Work API fetch will done in next setup view
                                [currentVC dismissViewControllerAnimated:YES completion:nil];
                            }
                        }
                        else {
                            [self performLicenseCheckWithLicenseStore:licenseStore];
                        }
                    });
                }
            }
        }];
    } else {
        if ([LicenseStore requiresLicenseKey] == true) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"already_licensed"] message:@"" actionOk:nil];
            });
        }
    }
}

+ (void) performLicenseCheckWithLicenseStore:(LicenseStore *)licenseStore {
    [licenseStore performLicenseCheckWithCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [WorkDataFetcher checkUpdateThreemaMDM:^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[AppDelegate sharedAppDelegate] isPresentingEnterLicense]) {
                            UIViewController *currentVC = [AppDelegate sharedAppDelegate].window.rootViewController;
                            [currentVC dismissViewControllerAnimated:YES completion:^{
                                [AppDelegate setupConnection];
                            }];
                        }
                    });
                } onError:^(NSError *error) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseMissing object:nil];
                }];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseMissing object:nil];
            }
        });
    }];
}

+ (void)handleThreemaDotIdUrl:(NSURL*)url hideAppChooser:(BOOL)hideAppChooser {
    BOOL composeWithChooser = false;
    NSString *targetId = [[url.path substringFromIndex:1] uppercaseString];
    if (targetId.length != kIdentityLen) {
        if (![[[url.path substringFromIndex:1] lowercaseString] isEqualToString:@"compose"]) {
            return;
        }
        
        composeWithChooser = true;
    }
    // Check if the "other" app (Work if we are not the Work app, or vice versa) is also installed.
    // If so, we need to prompt the user for what to do.
    BOOL mustDisplayAppChooser = NO;
    BOOL isWorkApp = [LicenseStore requiresLicenseKey];
    if (isWorkApp) {
        // This is the Work app. Check if the regular app is installed.
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"threema://app"]]) {
            mustDisplayAppChooser = YES;
        }
    } else {
        // This is the regular app. Check if the Work app is installed.
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"threemawork://app"]]) {
            mustDisplayAppChooser = YES;
        }
    }
    
    NSString *text = [[url.query dictionaryFromQueryComponents] objectForKey:@"text"][0];
    text = [text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (mustDisplayAppChooser && hideAppChooser == false) {
        NSString *newQuery;
        if (composeWithChooser) {
            if (text) {
                newQuery = [NSString stringWithFormat:@"text=%@", text];
            } else {
                // there is no text, we can't show the chooser
                return;
            }
        } else {
            if (text) {
                newQuery = [NSString stringWithFormat:@"id=%@&text=%@", targetId, text];
            } else {
                newQuery = [NSString stringWithFormat:@"id=%@", targetId];
            }
        }
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[BundleUtil localizedStringForKey:@"Open in ..."] message:url.absoluteString preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Threema" style:0 handler:^(UIAlertAction * _Nonnull action) {
            if (!isWorkApp) {
                if (composeWithChooser) {
                    [URLHandler handleComposeWithChooser:text query:[url.query dictionaryFromQueryComponents]];
                } else {
                    [URLHandler handleAddIdentity:targetId compose:YES query:[url.query dictionaryFromQueryComponents]];
                }
            } else {
                NSURL *newUrl = [NSURL URLWithString:[NSString stringWithFormat:@"threema://compose?%@", newQuery]];
                [[UIApplication sharedApplication] openURL:newUrl options:@{} completionHandler:nil];
            }
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Threema Work" style:0 handler:^(UIAlertAction * _Nonnull action) {
            if (isWorkApp) {
                if (composeWithChooser) {
                    [URLHandler handleComposeWithChooser:text query:[url.query dictionaryFromQueryComponents]];
                } else {
                    [URLHandler handleAddIdentity:targetId compose:YES query:[url.query dictionaryFromQueryComponents]];
                }
            } else {
                NSURL *newUrl = [NSURL URLWithString:[NSString stringWithFormat:@"threemawork://compose?%@", newQuery]];
                [[UIApplication sharedApplication] openURL:newUrl options:@{} completionHandler:nil];
            }
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction * _Nonnull action) {}]];
        
        [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:alertController animated:YES completion:nil];
    } else {
        if (composeWithChooser) {
            [URLHandler handleComposeWithChooser:text query:[url.query dictionaryFromQueryComponents]];
        } else {
            [URLHandler handleAddIdentity:targetId compose:YES query:[url.query dictionaryFromQueryComponents]];
        }
    }
}

+ (void)handleAddIdentity:(NSString*)targetId compose:(BOOL)compose query:(NSDictionary*)query {
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    if ([mdmSetup disableAddContact]) {
        /* Ensure this contact already exists, as we are not allowed to add any new ones */
        if ([[ContactStore sharedContactStore] contactForIdentity:targetId] == nil) {
            return;
        }
    }
    
    if ([targetId isEqualToString:[[MyIdentityStore sharedMyIdentityStore] identity]]) {
        return;
    }
    
    /* add this ID to the contacts */
    [[ContactStore sharedContactStore] addContactWithIdentity:targetId verificationLevel:kVerificationLevelUnverified onCompletion:^(ContactEntity *contact, BOOL alreadyExists) {
        
        if (compose && [query objectForKey:@"text"][0] != nil) {
            ShareController *shareController = [[ShareController alloc] init];
            shareController.contact = contact;
            shareController.text = [query objectForKey:@"text"][0];
            if ([[query objectForKey:@"image"][0] isEqualToString:@"pasteboard"]) {
                shareController.image = [self decryptPasteboardImageWithKey:[query objectForKey:@"key"][0]];
            }
            [shareController startShare];
        } else {
            /* just show contact details */
            NSDictionary *dictionary = @{kKeyContact: contact, @"fromURL": @YES};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowContact object:nil userInfo:dictionary];
        }
    } onError:^(NSError *error) {
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == 404) {
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:[BundleUtil localizedStringForKey:@"identity_not_found_title"] message:[BundleUtil localizedStringForKey:@"identity_not_found_message"] actionOk:nil];
        } else {
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        }
    }];
}

+ (void)handleComposeWithChooser:(NSString *)text query:(NSDictionary*)query {
    ShareController *shareController = [[ShareController alloc] init];
    shareController.text = [query objectForKey:@"text"][0];
    if ([[query objectForKey:@"image"][0] isEqualToString:@"pasteboard"]) {
        shareController.image = [self decryptPasteboardImageWithKey:[query objectForKey:@"key"][0]];
    }
    [shareController startShare];
}

+ (BOOL)handleShortCutItem:(UIApplicationShortcutItem *)shortCutItem {
    if ([shortCutItem.type isEqualToString:@"ch.threema.newmessage"]) {
        [self composeMessage];
        
        return YES;
    } else if ([shortCutItem.type isEqualToString:@"ch.threema.myid"]) {
        UITabBarController *mainTabBar = [AppDelegate getMainTabBarController];
        mainTabBar.selectedIndex = kMyIdentityTabBarIndex;

        return YES;
    } else if ([shortCutItem.type isEqualToString:@"ch.threema.scanid"]) {
        if ([ScanIdentityController canScan] == NO) {
            return NO;
        }
        
        MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
        if (mdmSetup.disableAddContact == true) {
            return NO;
        }

        
        UITabBarController *mainTabBar = [AppDelegate getMainTabBarController];
        
        ScanIdentityController *scanController = [[ScanIdentityController alloc] init];
        scanController.containingViewController = mainTabBar;
        scanController.expectedIdentity = nil;
        [scanController startScan];
        
        return YES;
   }
    
    return NO;
}

+ (void)composeMessage {
    ShareController *shareController = [[ShareController alloc] init];
    [shareController startShare];
}

+ (UIImage*)decryptPasteboardImageWithKey:(NSString*)keyHex {
    
    if (keyHex.length == 0) {
        /* no key - assume unencrypted image on pasteboard */
        return [[UIPasteboard generalPasteboard] image];
    }
    
    NSData *key = [keyHex decodeHex];
    if (key.length != kCCKeySizeAES256)
        return nil;
    
    NSData *imageDataEncrypted = [[UIPasteboard generalPasteboard] dataForPasteboardType:PASTEBOARD_IMAGE_UTI];
    if (imageDataEncrypted == nil)
        return nil;
    
    char *imagebuf = malloc(imageDataEncrypted.length);
    if (imagebuf == NULL)
        return nil;
    
    size_t size_out = 0;
    if (CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, NULL,
                imageDataEncrypted.bytes, imageDataEncrypted.length, imagebuf, imageDataEncrypted.length, &size_out) != kCCSuccess) {
        DDLogWarn(@"Pasteboard image decryption failed");
        free(imagebuf);
        return nil;
    }
    
    DDLogInfo(@"Pasteboard image decrypted successfully (%zu bytes)", size_out);
    
    NSData *imageData = [NSData dataWithBytesNoCopy:imagebuf length:size_out freeWhenDone:YES];
    
    return [UIImage imageWithData:imageData];
}

@end
