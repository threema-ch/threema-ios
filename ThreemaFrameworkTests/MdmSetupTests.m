//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

#import <XCTest/XCTest.h>
#import <OCMockito/OCMockito.h>
#import <OCHamcrest/OCHamcrest.h>
#import <ThreemaFramework/MDMSetup.h>
#import "MyIdentityStore.h"
#import "LicenseStore.h"
#import "UserSettings.h"


#define MOCKITO_SHORTHAND

@interface MdmSetupTests : XCTestCase
@end

@implementation MdmSetupTests {
    __strong Class _mockMyIdentityStoreClass;
    MyIdentityStore* _mockMyIdentityStore;
    __strong Class _mockUserSettingsClass;
    UserSettings* _mockUserSettings;
    __strong Class _mockLicenseStoreClass;
    LicenseStore* _mockLicenseStore;
    
    NSNumber *_yes;
    NSNumber *_no;
}

- (void)setUp {
    [super setUp];

    _mockUserSettingsClass = mockClass([UserSettings class]);
    _mockUserSettings = mock([UserSettings class]);
    stubSingleton(_mockUserSettingsClass, sharedUserSettings);
    [given([UserSettings sharedUserSettings]) willReturn:_mockUserSettings];

    _mockLicenseStoreClass = mockClass([LicenseStore class]);
    _mockLicenseStore = mock([LicenseStore class]);
    stubSingleton(_mockLicenseStoreClass, sharedLicenseStore);
    [given([LicenseStore sharedLicenseStore]) willReturn:_mockLicenseStore];

    _mockMyIdentityStoreClass = mockClass([MyIdentityStore class]);
    _mockMyIdentityStore = mock([MyIdentityStore class]);
    stubSingleton(_mockMyIdentityStoreClass, sharedMyIdentityStore);
    [given([MyIdentityStore sharedMyIdentityStore]) willReturn:_mockMyIdentityStore];
    
    [self delMdm];

    _yes = [[NSNumber alloc] initWithUnsignedInt:1];
    _no = [[NSNumber alloc] initWithUnsignedInt:0];
}

- (void)tearDown {
    stopMocking(_mockUserSettings);
    stopMocking(_mockUserSettingsClass);
    _mockUserSettings = nil;
    _mockUserSettingsClass = nil;
    
    stopMocking(_mockLicenseStore);
    stopMocking(_mockLicenseStoreClass);
    _mockLicenseStore = nil;
    _mockLicenseStoreClass = nil;

    stopMocking(_mockMyIdentityStore);
    stopMocking(_mockMyIdentityStoreClass);
    _mockMyIdentityStore = nil;
    _mockMyIdentityStoreClass = nil;
    
    [self delMdm];

    [super tearDown];
}

- (void)delMdm {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:MDM_CONFIGURATION_KEY];
    [defaults removeObjectForKey:MDM_THREEMA_CONFIGURATION_KEY];
    [defaults synchronize];
    [MDMSetup clearMdmCache];
}

- (void)setMdm:(NSDictionary*)companyMdm threemaMdm:(NSDictionary*)threemaMdm {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (companyMdm != nil) {
        [defaults setObject:companyMdm forKey:MDM_CONFIGURATION_KEY];
    }
    if (threemaMdm != nil) {
        [defaults setObject:threemaMdm forKey:MDM_THREEMA_CONFIGURATION_KEY];
    }
    [defaults synchronize];
}

- (void)setEmptyMDM {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:nil forKey:MDM_CONFIGURATION_KEY];
    [defaults setObject:nil forKey:MDM_THREEMA_CONFIGURATION_KEY];
    [defaults synchronize];
    [MDMSetup clearMdmCache];
}

- (void)testLoadLicenseInfo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];

    id keys[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD };
    id objects[] = { @"tester", @"testi123"};
    NSUInteger count = sizeof(objects) / sizeof(id);
    NSDictionary* companyMdm = [NSDictionary dictionaryWithObjects:objects forKeys:keys count:count];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    [mdmSetup loadLicenseInfo];

    [verify(_mockLicenseStore) setLicenseUsername:@"tester"];
    [verify(_mockLicenseStore) setLicensePassword:@"testi123"];
}

- (void)testLoadRenewableValues {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    [self setMdm:[self getAllMdmParameters:NO] threemaMdm:nil];

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup loadRenewableValues];
    
    [verify(_mockLicenseStore) setLicenseUsername:@"tester"];
    [verify(_mockLicenseStore) setLicensePassword:@"test1234"];
    
    [verifyCount(_mockMyIdentityStore, times(0)) setPushFromName:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setFirstName:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setLastName:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCsi:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCategory:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDEmail:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDPhone:anything()];

    XCTAssertTrue([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(1)) setBlockUnknown:YES];
    [verifyCount(_mockUserSettings, times(1)) setSyncContacts:YES];
    
    XCTAssertTrue([mdmSetup disableSaveToGallery]);
    XCTAssertTrue([mdmSetup disableAddContact]);
    XCTAssertTrue([mdmSetup disableExport]);
    XCTAssertTrue([mdmSetup disableBackups]);
    XCTAssertTrue([mdmSetup disableIdExport]);
    XCTAssertTrue([mdmSetup disableSystemBackups]);
    XCTAssertTrue([mdmSetup disableMessagePreview]);
    XCTAssertTrue([mdmSetup disableSendProfilePicture]);
    XCTAssertTrue([mdmSetup disableCalls]);
    XCTAssertTrue([mdmSetup disableVideoCalls]);
    XCTAssertTrue([mdmSetup disableGroupCalls]);
    XCTAssertTrue([mdmSetup disableCreateGroup]);
    XCTAssertTrue([mdmSetup disableWeb]);
        
    XCTAssertTrue([mdmSetup skipWizard]);
    XCTAssertTrue([mdmSetup safeEnable]);
    XCTAssertEqual(@"87654321", [mdmSetup safePassword]);
    XCTAssertEqual(@"http://test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"server-password", [mdmSetup safeServerPassword]);
    XCTAssertFalse([mdmSetup safeRestoreEnable]);
    XCTAssertEqual(@"ECHOECHO", [mdmSetup safeRestoreId]);
    XCTAssertEqual(@"^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"threema.ch", [mdmSetup webHosts]);
}

- (void)testLoadIDCreationValues {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    [self setMdm:[self getAllMdmParameters:NO] threemaMdm:nil];

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    [mdmSetup loadIDCreationValues];
    
    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()];
    [verifyCount(_mockLicenseStore, times(0)) setLicensePassword:anything()];
    
    [verifyCount(_mockMyIdentityStore, times(1)) setPushFromName:@"Eieri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:@"Heiri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:@"Heirassa"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:@"customer-id"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:@"category"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDEmail:@"linked@email.com"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDPhone:@"111"];
    
    XCTAssertTrue([mdmSetup readonlyProfile]);
    
    [verifyCount(_mockUserSettings, times(0)) setBlockUnknown:anything()];
    [verifyCount(_mockUserSettings, times(1)) setSyncContacts:anything()];

    
    XCTAssertTrue([mdmSetup disableSaveToGallery]);
    XCTAssertTrue([mdmSetup disableAddContact]);
    XCTAssertTrue([mdmSetup disableExport]);
    XCTAssertTrue([mdmSetup disableBackups]);
    XCTAssertTrue([mdmSetup disableIdExport]);
    XCTAssertTrue([mdmSetup disableSystemBackups]);
    XCTAssertTrue([mdmSetup disableMessagePreview]);
    XCTAssertTrue([mdmSetup disableSendProfilePicture]);
    XCTAssertTrue([mdmSetup disableCalls]);
    XCTAssertTrue([mdmSetup disableGroupCalls]);
    XCTAssertTrue([mdmSetup disableVideoCalls]);
    XCTAssertTrue([mdmSetup disableCreateGroup]);
    XCTAssertTrue([mdmSetup disableWeb]);
    
    XCTAssertTrue([mdmSetup skipWizard]);
    XCTAssertEqual(_yes, [mdmSetup safeEnable]);
    XCTAssertEqual(@"87654321", [mdmSetup safePassword]);
    XCTAssertEqual(@"http://test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"server-password", [mdmSetup safeServerPassword]);
    XCTAssertFalse([mdmSetup safeRestoreEnable]);
    XCTAssertEqual(@"ECHOECHO", [mdmSetup safeRestoreId]);
    XCTAssertEqual(@"^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"threema.ch", [mdmSetup webHosts]);
}

- (void)testHasIDBackup {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    id keys[] = { MDM_KEY_ID_BACKUP };
    id objects[] = { @"XXXX-XXXX-..." };
    NSUInteger count = sizeof(objects) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objects forKeys:keys count:count];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    BOOL result = [mdmSetup hasIDBackup];
    
    XCTAssertTrue(result);
    XCTAssertEqual(@"XXXX-XXXX-...", mdmSetup.idBackup);
    XCTAssertNil(mdmSetup.idBackupPassword);
}

/// Bestehende Firmen/Threema MDM-Parameter werden von renewable Threema MDM Parameter überschrieben (kein "setup" sync)
- (void)testApplyThreemaMdmWithCompanyMdmAndThreemaMdmDoOverrideSetupNo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];

    // Company-MDM and "old" Threema-MDM are equal
    NSDictionary *oldWorkData = @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:[self getAllMdmParameters:NO] threemaMdm:oldWorkData];

    // new Threema-MDM (override)
    id keysThreemaMdm[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_NICKNAME, MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_CATEGORY, MDM_KEY_LINKED_EMAIL, MDM_KEY_LINKED_PHONE, MDM_KEY_CONTACT_SYNC, MDM_KEY_READONLY_PROFILE, MDM_KEY_BLOCK_UNKNOWN, MDM_KEY_HIDE_INACTIVE_IDS, MDM_KEY_DISABLE_SAVE_TO_GALLERY, MDM_KEY_DISABLE_ADD_CONTACT, MDM_KEY_DISABLE_EXPORT, MDM_KEY_DISABLE_BACKUPS, MDM_KEY_DISABLE_ID_EXPORT, MDM_KEY_DISABLE_SYSTEM_BACKUPS, MDM_KEY_DISABLE_MESSAGE_PREVIEW, MDM_KEY_DISABLE_SEND_PROFILE_PICTURE, MDM_KEY_DISABLE_CALLS, MDM_KEY_DISABLE_VIDEO_CALLS, MDM_KEY_DISABLE_GROUP_CALLS, MDM_KEY_SKIP_WIZARD, MDM_KEY_DISABLE_CREATE_GROUP, MDM_KEY_DISABLE_WEB, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_SERVER_USERNAME, MDM_KEY_SAFE_SERVER_PASSWORD, MDM_KEY_SAFE_RESTORE_ENABLE, MDM_KEY_SAFE_RESTORE_ID, MDM_KEY_SAFE_PASSWORD_PATTERN, MDM_KEY_SAFE_PASSWORD_MESSAGE, MDM_KEY_WEB_HOSTS, MDM_KEY_DISABLE_SHARE_MEDIA, MDM_KEY_DISABLE_WORK_DIRECTORY};
    id objectsThreemaMdm[] = { @"new-tester", @"new-test1234", @"New-Eieri", @"New-Heiri", @"New-Heirassa", @"new-customer-id", @"new-category", @"new-linked@email.com", @"222", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", _no, @"http://new-test.com", @"new-server-user", @"new-server-password", @"1", @"EINSZWEI", @"new-^[0-9]{1,15}$", @"New-Wrong-password-pattern", @"new.threema.ch", @"0", @"0"};
    NSUInteger countThreemaMdm = sizeof(objectsThreemaMdm) / sizeof(id);
    NSDictionary *threemaMdm = [NSDictionary dictionaryWithObjects:objectsThreemaMdm forKeys:keysThreemaMdm count:countThreemaMdm];

    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:threemaMdm}};
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    // Threema MDM can't set the license username and password
    [verify(_mockLicenseStore) setLicenseUsername:@"tester"];
    [verify(_mockLicenseStore) setLicensePassword:@"test1234"];
    
    [verifyCount(_mockMyIdentityStore, times(1)) setPushFromName:@"New-Eieri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:@"New-Heiri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:@"New-Heirassa"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:@"new-customer-id"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:@"new-category"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDEmail:@"linked@email.com"]; // not renewable
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDPhone:@"111"]; // not renewable
    
    XCTAssertFalse([mdmSetup readonlyProfile]);
    
    [verifyCount(_mockUserSettings, times(1)) setBlockUnknown:NO];
    [verifyCount(_mockUserSettings, times(1)) setHideStaleContacts:NO];
    [verifyCount(_mockUserSettings, times(2)) setSyncContacts:NO];
    
    XCTAssertFalse([mdmSetup disableSaveToGallery]);
    XCTAssertFalse([mdmSetup disableAddContact]);
    XCTAssertFalse([mdmSetup disableExport]);
    XCTAssertFalse([mdmSetup disableBackups]);
    XCTAssertFalse([mdmSetup disableIdExport]);
    XCTAssertFalse([mdmSetup disableSystemBackups]);
    XCTAssertFalse([mdmSetup disableMessagePreview]);
    XCTAssertFalse([mdmSetup disableSendProfilePicture]);
    XCTAssertFalse([mdmSetup disableCalls]);
    XCTAssertFalse([mdmSetup disableVideoCalls]);
    XCTAssertFalse([mdmSetup disableGroupCalls]);
    XCTAssertFalse([mdmSetup disableCreateGroup]);
    XCTAssertFalse([mdmSetup disableWeb]);
    XCTAssertFalse([mdmSetup disableShareMedia]);
    XCTAssertFalse([mdmSetup disableWorkDirectory]);
    
    XCTAssertTrue([mdmSetup skipWizard]); // not renewable
    XCTAssertEqual(_no, [mdmSetup safeEnable]);
    XCTAssertEqual(@"87654321", [mdmSetup safePassword]);
    XCTAssertEqual(@"http://new-test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"new-server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"new-server-password", [mdmSetup safeServerPassword]);
    XCTAssertFalse([mdmSetup safeRestoreEnable]); // not renewable
    XCTAssertEqual(@"ECHOECHO", [mdmSetup safeRestoreId]); // not renewable
    XCTAssertEqual(@"new-^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"New-Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"new.threema.ch", [mdmSetup webHosts]);
}

/// Bestehende Firmen MDM-Parameter werden von renewable Threema MDM-Parameter überschrieben (kein "setup" sync)
- (void)testApplyThreemaMdmWithCompanyMdmAndNoThreemaMdmDoOverrideSetupNo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM and NO "old" Threema-MDM
    [self setMdm:[self getAllMdmParameters:NO] threemaMdm:nil];
    
    // "new" Threema-MDM (override)
    id keysThreemaMdm[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_NICKNAME, MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_CATEGORY, MDM_KEY_LINKED_EMAIL, MDM_KEY_LINKED_PHONE, MDM_KEY_CONTACT_SYNC, MDM_KEY_READONLY_PROFILE, MDM_KEY_BLOCK_UNKNOWN, MDM_KEY_HIDE_INACTIVE_IDS, MDM_KEY_DISABLE_SAVE_TO_GALLERY, MDM_KEY_DISABLE_ADD_CONTACT, MDM_KEY_DISABLE_EXPORT, MDM_KEY_DISABLE_BACKUPS, MDM_KEY_DISABLE_ID_EXPORT, MDM_KEY_DISABLE_SYSTEM_BACKUPS, MDM_KEY_DISABLE_MESSAGE_PREVIEW, MDM_KEY_DISABLE_SEND_PROFILE_PICTURE, MDM_KEY_DISABLE_CALLS, MDM_KEY_DISABLE_VIDEO_CALLS, MDM_KEY_DISABLE_GROUP_CALLS, MDM_KEY_SKIP_WIZARD, MDM_KEY_DISABLE_CREATE_GROUP, MDM_KEY_DISABLE_WEB, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_SERVER_USERNAME, MDM_KEY_SAFE_SERVER_PASSWORD, MDM_KEY_SAFE_RESTORE_ENABLE, MDM_KEY_SAFE_RESTORE_ID, MDM_KEY_SAFE_PASSWORD_PATTERN, MDM_KEY_SAFE_PASSWORD_MESSAGE, MDM_KEY_WEB_HOSTS, MDM_KEY_DISABLE_SHARE_MEDIA, MDM_KEY_DISABLE_WORK_DIRECTORY};
    id objectsThreemaMdm[] = { @"new-tester", @"new-test1234", @"New-Eieri", @"New-Heiri", @"New-Heirassa", @"new-customer-id", @"new-category", @"new-linked@email.com", @"222", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", _no, @"http://new-test.com", @"new-server-user", @"new-server-password", @"1", @"EINSZWEI", @"new-^[0-9]{1,15}$", @"New-Wrong-password-pattern", @"new.threema.ch", @"0", @"0"};
    NSUInteger countThreemaMdm = sizeof(objectsThreemaMdm) / sizeof(id);
    NSDictionary *threemaMdm = [NSDictionary dictionaryWithObjects:objectsThreemaMdm forKeys:keysThreemaMdm count:countThreemaMdm];
    
    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:threemaMdm}};
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    // Threema MDM can't set the license username and password
    [verify(_mockLicenseStore) setLicenseUsername:@"tester"];
    [verify(_mockLicenseStore) setLicensePassword:@"test1234"];
    
    [verifyCount(_mockMyIdentityStore, times(1)) setPushFromName:@"New-Eieri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:@"New-Heiri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:@"New-Heirassa"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:@"new-customer-id"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:@"new-category"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDEmail:@"linked@email.com"]; // not renewable
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDPhone:@"111"]; // not renewable
    
    XCTAssertFalse([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(1)) setBlockUnknown:NO];
    [verifyCount(_mockUserSettings, times(2)) setSyncContacts:NO];
    [verifyCount(_mockUserSettings, times(1)) setHideStaleContacts:NO];
    XCTAssertFalse([mdmSetup disableSaveToGallery]);
    XCTAssertFalse([mdmSetup disableAddContact]);
    XCTAssertFalse([mdmSetup disableExport]);
    XCTAssertFalse([mdmSetup disableBackups]);
    XCTAssertFalse([mdmSetup disableIdExport]);
    XCTAssertFalse([mdmSetup disableSystemBackups]);
    XCTAssertFalse([mdmSetup disableMessagePreview]);
    XCTAssertFalse([mdmSetup disableSendProfilePicture]);
    XCTAssertFalse([mdmSetup disableCalls]);
    XCTAssertFalse([mdmSetup disableVideoCalls]);
    XCTAssertFalse([mdmSetup disableGroupCalls]);
    XCTAssertFalse([mdmSetup disableCreateGroup]);
    XCTAssertFalse([mdmSetup disableWeb]);
    XCTAssertFalse([mdmSetup disableShareMedia]);
    XCTAssertFalse([mdmSetup disableWorkDirectory]);
    
    XCTAssertTrue([mdmSetup skipWizard]); // not renewable
    XCTAssertEqual(_no, [mdmSetup safeEnable]);
    XCTAssertEqual(@"87654321", [mdmSetup safePassword]);
    XCTAssertEqual(@"http://new-test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"new-server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"new-server-password", [mdmSetup safeServerPassword]);
    XCTAssertFalse([mdmSetup safeRestoreEnable]); // not renewable
    XCTAssertEqual(@"ECHOECHO", [mdmSetup safeRestoreId]); // not renewable
    XCTAssertEqual(@"new-^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"New-Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"new.threema.ch", [mdmSetup webHosts]);
}

/// Keine bestehende MDM-Parameter, alle renewable Threema MDM-Parameter werden übernommen (kein "setup" sync)
- (void)testApplyThreemaMdmWithNoCompanyMdmAndNoThreemaMdmDoOverrideSetupNo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // No Company-MDM and no "old" Threema-MDM are equal
    
    // new Threema-MDM (override)
    id keysThreemaMdm[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_NICKNAME, MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_CATEGORY, MDM_KEY_LINKED_EMAIL, MDM_KEY_LINKED_PHONE, MDM_KEY_CONTACT_SYNC, MDM_KEY_READONLY_PROFILE, MDM_KEY_BLOCK_UNKNOWN, MDM_KEY_HIDE_INACTIVE_IDS, MDM_KEY_DISABLE_SAVE_TO_GALLERY, MDM_KEY_DISABLE_ADD_CONTACT, MDM_KEY_DISABLE_EXPORT, MDM_KEY_DISABLE_BACKUPS, MDM_KEY_DISABLE_ID_EXPORT, MDM_KEY_DISABLE_SYSTEM_BACKUPS, MDM_KEY_DISABLE_MESSAGE_PREVIEW, MDM_KEY_DISABLE_SEND_PROFILE_PICTURE, MDM_KEY_DISABLE_CALLS, MDM_KEY_DISABLE_VIDEO_CALLS, MDM_KEY_DISABLE_GROUP_CALLS,MDM_KEY_SKIP_WIZARD, MDM_KEY_DISABLE_CREATE_GROUP, MDM_KEY_DISABLE_WEB, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_SERVER_USERNAME, MDM_KEY_SAFE_SERVER_PASSWORD, MDM_KEY_SAFE_RESTORE_ENABLE, MDM_KEY_SAFE_RESTORE_ID, MDM_KEY_SAFE_PASSWORD_PATTERN, MDM_KEY_SAFE_PASSWORD_MESSAGE, MDM_KEY_WEB_HOSTS, MDM_KEY_DISABLE_SHARE_MEDIA, MDM_KEY_DISABLE_WORK_DIRECTORY};
    id objectsThreemaMdm[] = { @"new-tester", @"new-test1234", @"New-Eieri", @"New-Heiri", @"New-Heirassa", @"new-customer-id", @"new-category", @"new-linked@email.com", @"222", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", @"0", _no, @"http://new-test.com", @"new-server-user", @"new-server-password", @"1", @"EINSZWEI", @"new-^[0-9]{1,15}$", @"New-Wrong-password-pattern", @"new.threema.ch", @"0", @"0"};
    NSUInteger countThreemaMdm = sizeof(objectsThreemaMdm) / sizeof(id);
    NSDictionary *threemaMdm = [NSDictionary dictionaryWithObjects:objectsThreemaMdm forKeys:keysThreemaMdm count:countThreemaMdm];
    
    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:threemaMdm}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    // Threema MDM can't set the license username and password
    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()];
    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()];
    
    [verifyCount(_mockMyIdentityStore, times(0)) setPushFromName:@"New-Heiri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:@"New-Heiri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:@"New-Heirassa"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:@"new-customer-id"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:@"new-category"];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDEmail:anything()]; // not renewable
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDPhone:anything()]; // not renewable
    
    XCTAssertFalse([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(1)) setBlockUnknown:NO];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN]);
    [verifyCount(_mockUserSettings, times(2)) setSyncContacts:NO];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]);
    [verifyCount(_mockUserSettings, times(1)) setHideStaleContacts:NO];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_HIDE_INACTIVE_IDS]);
    XCTAssertFalse([mdmSetup disableSaveToGallery]);
    XCTAssertFalse([mdmSetup disableAddContact]);
    XCTAssertFalse([mdmSetup disableExport]);
    XCTAssertFalse([mdmSetup disableBackups]);
    XCTAssertFalse([mdmSetup disableIdExport]);
    XCTAssertFalse([mdmSetup disableSystemBackups]);
    XCTAssertFalse([mdmSetup disableMessagePreview]);
    XCTAssertFalse([mdmSetup disableSendProfilePicture]);
    XCTAssertFalse([mdmSetup disableCalls]);
    XCTAssertFalse([mdmSetup disableVideoCalls]);
    XCTAssertFalse([mdmSetup disableGroupCalls]);
    XCTAssertFalse([mdmSetup disableCreateGroup]);
    XCTAssertFalse([mdmSetup disableWeb]);
    XCTAssertFalse([mdmSetup disableShareMedia]);
    XCTAssertFalse([mdmSetup disableWorkDirectory]);
    
    XCTAssertFalse([mdmSetup skipWizard]); // not renewable
    XCTAssertEqual(_no, [mdmSetup safeEnable]);
    XCTAssertNil([mdmSetup safePassword]);
    XCTAssertEqual(@"http://new-test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"new-server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"new-server-password", [mdmSetup safeServerPassword]);
    XCTAssertTrue([mdmSetup safeRestoreEnable]); // not renewable
    XCTAssertNil([mdmSetup safeRestoreId]); // not renewable
    XCTAssertEqual(@"new-^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"New-Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"new.threema.ch", [mdmSetup webHosts]);
    
    XCTAssertNil([_mockLicenseStore licenseUsername]);
    XCTAssertNil([_mockLicenseStore licensePassword]);
}

/// Bestehende Threema MDM-Parameter weden entfernt
- (void)testApplyThreemaMdmMissingParametersDoOverrideSetupNo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // "old" Threema-MDM
    NSDictionary *oldWorkData = @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:nil threemaMdm:oldWorkData];
    
    // "new" Threema-MDM (+)
    id keysThreemaMdm[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_LINKED_EMAIL, MDM_KEY_LINKED_PHONE, MDM_KEY_SKIP_WIZARD, };
    id objectsThreemaMdm[] = { @"new-tester", @"new-test1234", @"new-linked@email.com", @"222", @"0" };
    NSUInteger countThreemaMdm = sizeof(objectsThreemaMdm) / sizeof(id);
    NSDictionary *threemaMdm = [NSDictionary dictionaryWithObjects:objectsThreemaMdm forKeys:keysThreemaMdm count:countThreemaMdm];
    
    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:threemaMdm}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    // Threema MDM can't set the license username and password
    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()];
    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()];

    [verifyCount(_mockMyIdentityStore, times(0)) setPushFromName:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDEmail:anything()]; // not renewable
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDPhone:anything()]; // not renewable
    
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:anything()];
    
    XCTAssertNil([_mockLicenseStore licenseUsername]);
    XCTAssertNil([_mockLicenseStore licensePassword]);
    
    XCTAssertFalse([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(0)) setBlockUnknown:anything()];
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN]);
    [verifyCount(_mockUserSettings, times(0)) setSyncContacts:anything()];
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]);
    [verifyCount(_mockUserSettings, times(0)) setHideStaleContacts:anything()];
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_HIDE_INACTIVE_IDS]);
    XCTAssertFalse([mdmSetup disableSaveToGallery]);
    XCTAssertFalse([mdmSetup disableAddContact]);
    XCTAssertFalse([mdmSetup disableExport]);
    XCTAssertFalse([mdmSetup disableBackups]);
    XCTAssertFalse([mdmSetup disableIdExport]);
    XCTAssertFalse([mdmSetup disableSystemBackups]);
    XCTAssertFalse([mdmSetup disableMessagePreview]);
    XCTAssertFalse([mdmSetup disableSendProfilePicture]);
    XCTAssertFalse([mdmSetup disableCalls]);
    XCTAssertFalse([mdmSetup disableVideoCalls]);
    XCTAssertFalse([mdmSetup disableGroupCalls]);
    XCTAssertFalse([mdmSetup disableCreateGroup]);
    XCTAssertFalse([mdmSetup disableWeb]);
    
    XCTAssertFalse([mdmSetup skipWizard]); // not renewable
    XCTAssertNil([mdmSetup safeEnable]);
    XCTAssertNil([mdmSetup safePassword]);
    XCTAssertNil([mdmSetup safeServerUrl]);
    XCTAssertNil([mdmSetup safeServerUsername]);
    XCTAssertNil([mdmSetup safeServerPassword]);
    XCTAssertTrue([mdmSetup safeRestoreEnable]);
    XCTAssertNil([mdmSetup safeRestoreId]);
    XCTAssertNil([mdmSetup safePasswordPattern]);
    XCTAssertNil([mdmSetup safePasswordMessage]);
    XCTAssertNil([mdmSetup webHosts]);
}

/// Bestehendes Threema MDM wird deaktiviert
- (void)testApplyThreemaMdmWithEmptyThreemaMdmDoOverrideSetupNo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // "old" Threema-MDM
    NSDictionary *oldWorkData = @{MDM_KEY_THREEMA_OVERRIDE:@true, MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:nil threemaMdm:oldWorkData];
    
    // NO "new" Threema-MDM
    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];

    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()];
    [verifyCount(_mockLicenseStore, times(0)) setLicensePassword:anything()];
    
    [verifyCount(_mockMyIdentityStore, times(0)) setPushFromName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDEmail:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDPhone:anything()];
    
    XCTAssertFalse([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(0)) setBlockUnknown:anything()];
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN]);
    [verifyCount(_mockUserSettings, times(0)) setSyncContacts:anything()];
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]);
    [verifyCount(_mockUserSettings, times(0)) setHideStaleContacts:anything()];
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_HIDE_INACTIVE_IDS]);
    XCTAssertFalse([mdmSetup disableSaveToGallery]);
    XCTAssertFalse([mdmSetup disableAddContact]);
    XCTAssertFalse([mdmSetup disableExport]);
    XCTAssertFalse([mdmSetup disableBackups]);
    XCTAssertFalse([mdmSetup disableIdExport]);
    XCTAssertFalse([mdmSetup disableSystemBackups]);
    XCTAssertFalse([mdmSetup disableMessagePreview]);
    XCTAssertFalse([mdmSetup disableSendProfilePicture]);
    XCTAssertFalse([mdmSetup disableCalls]);
    XCTAssertFalse([mdmSetup disableVideoCalls]);
    XCTAssertFalse([mdmSetup disableGroupCalls]);
    XCTAssertFalse([mdmSetup disableCreateGroup]);
    XCTAssertFalse([mdmSetup disableWeb]);
    
    XCTAssertFalse([mdmSetup skipWizard]);
    XCTAssertNil([mdmSetup safeEnable]);
    XCTAssertNil([mdmSetup safePassword]);
    XCTAssertNil([mdmSetup safeServerUrl]);
    XCTAssertNil([mdmSetup safeServerUsername]);
    XCTAssertNil([mdmSetup safeServerPassword]);
    XCTAssertTrue([mdmSetup safeRestoreEnable]);
    XCTAssertNil([mdmSetup safeRestoreId]);
    XCTAssertNil([mdmSetup safePasswordPattern]);
    XCTAssertNil([mdmSetup safePasswordMessage]);
    XCTAssertNil([mdmSetup webHosts]);
}

/// MDM ohne `MDM_KEY_THREEMA_CONFIGURATION` führt zu keiner MDM Änderung
- (void)testApplyThreemaMdmWithNoThreemaMdmDoOverrideSetupNo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // "old" Threema-MDM
    NSDictionary *oldWorkData = @{MDM_KEY_THREEMA_OVERRIDE:@true, MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:nil threemaMdm:oldWorkData];
    
    // NO "new" Threema-MDM
    NSDictionary *workData = @{};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];

    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()];
    [verifyCount(_mockLicenseStore, times(0)) setLicensePassword:anything()];
    
    [verifyCount(_mockMyIdentityStore, times(1)) setPushFromName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:anything()];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDEmail:anything()];
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDPhone:anything()];

    XCTAssertTrue([mdmSetup readonlyProfile]);
    
    [verifyCount(_mockUserSettings, times(1)) setBlockUnknown:anything()];
    [verifyCount(_mockUserSettings, times(2)) setSyncContacts:anything()];

    XCTAssertTrue([mdmSetup disableSaveToGallery]);
    XCTAssertTrue([mdmSetup disableAddContact]);
    XCTAssertTrue([mdmSetup disableExport]);
    XCTAssertTrue([mdmSetup disableBackups]);
    XCTAssertTrue([mdmSetup disableIdExport]);
    XCTAssertTrue([mdmSetup disableSystemBackups]);
    XCTAssertTrue([mdmSetup disableMessagePreview]);
    XCTAssertTrue([mdmSetup disableSendProfilePicture]);
    XCTAssertTrue([mdmSetup disableCalls]);
    XCTAssertTrue([mdmSetup disableGroupCalls]);
    XCTAssertTrue([mdmSetup disableVideoCalls]);
    XCTAssertTrue([mdmSetup disableCreateGroup]);
    XCTAssertTrue([mdmSetup disableWeb]);
    
    XCTAssertFalse([mdmSetup skipWizard]);
    XCTAssertEqual(_yes, [mdmSetup safeEnable]);
    XCTAssertNil([mdmSetup safePassword]);
    XCTAssertEqual(@"http://test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"server-password", [mdmSetup safeServerPassword]);
    XCTAssertTrue([mdmSetup safeRestoreEnable]);
    XCTAssertNil([mdmSetup safeRestoreId]);
    XCTAssertEqual(@"^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"threema.ch", [mdmSetup webHosts]);
}

/// Bestehendes Firmen MDM wird mit Threema MDM aktualisiert ("normaler" sync: NICHT renewable Parameter werden NICHT übernommen)
- (void)testApplyThreemaMdmWithCompanyMdmAddingThreemaMdmDoOverrideSetupNo {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM and NO "old" Threema-MDM
    id keysCompanyMdm[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_LINKED_EMAIL, MDM_KEY_LINKED_PHONE, MDM_KEY_SKIP_WIZARD, MDM_KEY_SAFE_PASSWORD, };
    id objectsCompanyMdm[] = { @"company-tester", @"company-test1234", @"company-linked@email.com", @"555", @"0", @"12345678" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    // "new" Threema-MDM (override)
    id keysMdm[] = { MDM_KEY_NICKNAME, MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_CATEGORY, MDM_KEY_CONTACT_SYNC, MDM_KEY_READONLY_PROFILE, MDM_KEY_BLOCK_UNKNOWN, MDM_KEY_HIDE_INACTIVE_IDS, MDM_KEY_DISABLE_SAVE_TO_GALLERY, MDM_KEY_DISABLE_ADD_CONTACT, MDM_KEY_DISABLE_EXPORT, MDM_KEY_DISABLE_BACKUPS, MDM_KEY_DISABLE_ID_EXPORT, MDM_KEY_DISABLE_SYSTEM_BACKUPS, MDM_KEY_DISABLE_MESSAGE_PREVIEW, MDM_KEY_DISABLE_SEND_PROFILE_PICTURE, MDM_KEY_DISABLE_CALLS, MDM_KEY_DISABLE_VIDEO_CALLS, MDM_KEY_DISABLE_GROUP_CALLS, MDM_KEY_SKIP_WIZARD, MDM_KEY_DISABLE_CREATE_GROUP, MDM_KEY_DISABLE_WEB, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_SERVER_USERNAME, MDM_KEY_SAFE_SERVER_PASSWORD, MDM_KEY_SAFE_RESTORE_ENABLE, MDM_KEY_SAFE_RESTORE_ID, MDM_KEY_SAFE_PASSWORD_PATTERN, MDM_KEY_SAFE_PASSWORD_MESSAGE, MDM_KEY_WEB_HOSTS, MDM_KEY_DISABLE_SHARE_MEDIA, MDM_KEY_DISABLE_WORK_DIRECTORY};
    id objectsMdm[] = { @"Eieri", @"Heiri", @"Heirassa", @"customer-id", @"category" ,@"1" ,@"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", _yes, @"http://test.com", @"server-user", @"server-password", @"0", @"ECHOECHO", @"^[0-9]{1,15}$", @"Wrong-password-pattern", @"new.threema.ch", @"1", @"1"};
    NSUInteger countMdm = sizeof(objectsMdm) / sizeof(id);
    NSDictionary *mdm = [NSDictionary dictionaryWithObjects:objectsMdm forKeys:keysMdm count:countMdm];

    
    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:mdm}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    [verify(_mockLicenseStore) setLicenseUsername:@"company-tester"];
    [verify(_mockLicenseStore) setLicensePassword:@"company-test1234"];
    
    [verifyCount(_mockMyIdentityStore, times(1)) setPushFromName:@"Eieri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:@"Heiri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:@"Heirassa"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:@"customer-id"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:@"category"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDEmail:@"company-linked@email.com"]; // not renewable
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDPhone:@"555"]; // not renewable
    
    XCTAssertTrue([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(1)) setBlockUnknown:YES];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN]);
    [verifyCount(_mockUserSettings, times(2)) setSyncContacts:YES];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]);
    [verifyCount(_mockUserSettings, times(1)) setHideStaleContacts:YES];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_HIDE_INACTIVE_IDS]);
    XCTAssertTrue([mdmSetup disableSaveToGallery]);
    XCTAssertTrue([mdmSetup disableAddContact]);
    XCTAssertTrue([mdmSetup disableExport]);
    XCTAssertTrue([mdmSetup disableBackups]);
    XCTAssertTrue([mdmSetup disableIdExport]);
    XCTAssertTrue([mdmSetup disableSystemBackups]);
    XCTAssertTrue([mdmSetup disableMessagePreview]);
    XCTAssertTrue([mdmSetup disableSendProfilePicture]);
    XCTAssertTrue([mdmSetup disableCalls]);
    XCTAssertTrue([mdmSetup disableVideoCalls]);
    XCTAssertTrue([mdmSetup disableGroupCalls]);
    XCTAssertTrue([mdmSetup disableCreateGroup]);
    XCTAssertTrue([mdmSetup disableWeb]);
    XCTAssertTrue([mdmSetup disableShareMedia]);
    XCTAssertTrue([mdmSetup disableWorkDirectory]);
    
    XCTAssertFalse([mdmSetup skipWizard]); // not renewable
    XCTAssertTrue([mdmSetup safeEnable]);
    XCTAssertEqual(@"12345678", [mdmSetup safePassword]);
    XCTAssertEqual(@"http://test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"server-password", [mdmSetup safeServerPassword]);
    XCTAssertTrue([mdmSetup safeRestoreEnable]); // not renewable
    XCTAssertNil([mdmSetup safeRestoreId]); // not renewable
    XCTAssertEqual(@"^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"new.threema.ch", [mdmSetup webHosts]);
}

/// Bestehendes Firmen MDM wird mit Threema MDM aktulisiert ("setup" sync: NICHT renewable Parameter werden übernommen)
- (void)testApplyThreemaMdmWithCompanyMdmAddingThreemaMdmDoOverrideSetupYes {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM and NO "old" Threema-MDM
    id keysCompanyMdm[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_LINKED_EMAIL, MDM_KEY_LINKED_PHONE, MDM_KEY_SKIP_WIZARD, MDM_KEY_SAFE_PASSWORD, };
    id objectsCompanyMdm[] = { @"company-tester", @"company-test1234", @"company-linked@email.com", @"555", @"0", @"12345678" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];

    // "new" Threema-MDM (override)
    id keysMdm[] = { MDM_KEY_NICKNAME, MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_CATEGORY, MDM_KEY_CONTACT_SYNC, MDM_KEY_READONLY_PROFILE, MDM_KEY_BLOCK_UNKNOWN, MDM_KEY_HIDE_INACTIVE_IDS, MDM_KEY_DISABLE_SAVE_TO_GALLERY, MDM_KEY_DISABLE_ADD_CONTACT, MDM_KEY_DISABLE_EXPORT, MDM_KEY_DISABLE_BACKUPS, MDM_KEY_DISABLE_ID_EXPORT, MDM_KEY_DISABLE_SYSTEM_BACKUPS, MDM_KEY_DISABLE_MESSAGE_PREVIEW, MDM_KEY_DISABLE_SEND_PROFILE_PICTURE, MDM_KEY_DISABLE_CALLS, MDM_KEY_DISABLE_VIDEO_CALLS, MDM_KEY_DISABLE_GROUP_CALLS, MDM_KEY_SKIP_WIZARD, MDM_KEY_DISABLE_CREATE_GROUP, MDM_KEY_DISABLE_WEB, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_SERVER_USERNAME, MDM_KEY_SAFE_SERVER_PASSWORD, MDM_KEY_SAFE_RESTORE_ENABLE, MDM_KEY_SAFE_RESTORE_ID, MDM_KEY_SAFE_PASSWORD_PATTERN, MDM_KEY_SAFE_PASSWORD_MESSAGE, MDM_KEY_WEB_HOSTS, MDM_KEY_DISABLE_SHARE_MEDIA, MDM_KEY_DISABLE_WORK_DIRECTORY};
    id objectsMdm[] = { @"Eieri", @"Heiri", @"Heirassa", @"customer-id", @"category" ,@"1" ,@"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", _yes, @"http://test.com", @"server-user", @"server-password", @"0", @"ECHOECHO", @"^[0-9]{1,15}$", @"Wrong-password-pattern", @"new.threema.ch", @"1", @"1"};
    NSUInteger countMdm = sizeof(objectsMdm) / sizeof(id);
    NSDictionary *mdm = [NSDictionary dictionaryWithObjects:objectsMdm forKeys:keysMdm count:countMdm];
    
    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:mdm}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    [verify(_mockLicenseStore) setLicenseUsername:@"company-tester"];
    [verify(_mockLicenseStore) setLicensePassword:@"company-test1234"];
    
    [verifyCount(_mockMyIdentityStore, times(1)) setPushFromName:@"Eieri"]; // not renewable
    [verifyCount(_mockMyIdentityStore, times(1)) setFirstName:@"Heiri"];
    [verifyCount(_mockMyIdentityStore, times(1)) setLastName:@"Heirassa"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCsi:@"customer-id"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCategory:@"category"];
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDEmail:@"company-linked@email.com"]; // not renewable
    [verifyCount(_mockMyIdentityStore, times(1)) setCreateIDPhone:@"555"]; // not renewable
    
    XCTAssertTrue([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(1)) setBlockUnknown:YES];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN]);
    [verifyCount(_mockUserSettings, times(2)) setSyncContacts:YES];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]);
    [verifyCount(_mockUserSettings, times(1)) setHideStaleContacts:YES];
    XCTAssertTrue([mdmSetup existsMdmKey:MDM_KEY_HIDE_INACTIVE_IDS]);
    XCTAssertTrue([mdmSetup disableSaveToGallery]);
    XCTAssertTrue([mdmSetup disableAddContact]);
    XCTAssertTrue([mdmSetup disableExport]);
    XCTAssertTrue([mdmSetup disableBackups]);
    XCTAssertTrue([mdmSetup disableIdExport]);
    XCTAssertTrue([mdmSetup disableSystemBackups]);
    XCTAssertTrue([mdmSetup disableMessagePreview]);
    XCTAssertTrue([mdmSetup disableSendProfilePicture]);
    XCTAssertTrue([mdmSetup disableCalls]);
    XCTAssertTrue([mdmSetup disableVideoCalls]);
    XCTAssertTrue([mdmSetup disableGroupCalls]);
    XCTAssertTrue([mdmSetup disableCreateGroup]);
    XCTAssertTrue([mdmSetup disableWeb]);
    XCTAssertTrue([mdmSetup disableShareMedia]);
    XCTAssertTrue([mdmSetup disableWorkDirectory]);
    
    XCTAssertTrue([mdmSetup skipWizard]); // not renewable
    XCTAssertTrue([mdmSetup safeEnable]);
    XCTAssertEqual(@"12345678", [mdmSetup safePassword]);
    XCTAssertEqual(@"http://test.com", [mdmSetup safeServerUrl]);
    XCTAssertEqual(@"server-user", [mdmSetup safeServerUsername]);
    XCTAssertEqual(@"server-password", [mdmSetup safeServerPassword]);
    XCTAssertFalse([mdmSetup safeRestoreEnable]); // not renewable
    XCTAssertEqual(@"ECHOECHO", [mdmSetup safeRestoreId]); // not renewable
    XCTAssertEqual(@"^[0-9]{1,15}$", [mdmSetup safePasswordPattern]);
    XCTAssertEqual(@"Wrong-password-pattern", [mdmSetup safePasswordMessage]);
    XCTAssertEqual(@"new.threema.ch", [mdmSetup webHosts]);
}

/// Work-Lizenz nicht gültig, gewisse renewable "MDM" Settings werden zurückgesetzt
- (void)testNoLicenseRequired {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:NO];
    
    // "old" Threema-MDM
    NSDictionary *oldWorkData = @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:nil threemaMdm:oldWorkData];

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    [verifyCount(_mockLicenseStore, times(0)) setLicenseUsername:anything()]; // not reset
    [verifyCount(_mockLicenseStore, times(0)) setLicensePassword:anything()]; // not reset
    
    [verifyCount(_mockMyIdentityStore, times(0)) setPushFromName:anything()]; // not reset
    [verifyCount(_mockMyIdentityStore, times(0)) setFirstName:anything()]; // not reset
    [verifyCount(_mockMyIdentityStore, times(0)) setLastName:anything()]; // not reset
    [verifyCount(_mockMyIdentityStore, times(0)) setCsi:anything()]; // not reset
    [verifyCount(_mockMyIdentityStore, times(0)) setCategory:anything()]; // not reset
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDEmail:anything()]; // not reset
    [verifyCount(_mockMyIdentityStore, times(0)) setCreateIDPhone:anything()]; // not reset
    
    XCTAssertFalse([mdmSetup readonlyProfile]);
    [verifyCount(_mockUserSettings, times(0)) setBlockUnknown:anything()]; // not reset
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN]);
    [verifyCount(_mockUserSettings, times(0)) setSyncContacts:anything()];
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]);
    [verifyCount(_mockUserSettings, times(0)) setHideStaleContacts:anything()]; // not reset
    XCTAssertFalse([mdmSetup existsMdmKey:MDM_KEY_HIDE_INACTIVE_IDS]);
    XCTAssertFalse([mdmSetup disableSaveToGallery]);
    XCTAssertFalse([mdmSetup disableAddContact]);
    XCTAssertFalse([mdmSetup disableExport]);
    XCTAssertFalse([mdmSetup disableBackups]);
    XCTAssertFalse([mdmSetup disableIdExport]);
    XCTAssertFalse([mdmSetup disableSystemBackups]);
    XCTAssertFalse([mdmSetup disableMessagePreview]);
    XCTAssertFalse([mdmSetup disableSendProfilePicture]);
    XCTAssertFalse([mdmSetup disableCalls]);
    XCTAssertFalse([mdmSetup disableVideoCalls]);
    XCTAssertFalse([mdmSetup disableGroupCalls]);
    XCTAssertFalse([mdmSetup disableCreateGroup]);
    XCTAssertFalse([mdmSetup disableWeb]);
    
    XCTAssertFalse([mdmSetup skipWizard]);
    XCTAssertNil([mdmSetup safeEnable]);
    XCTAssertNil([mdmSetup safePassword]);
    XCTAssertNil([mdmSetup safeServerUrl]);
    XCTAssertNil([mdmSetup safeServerUsername]);
    XCTAssertNil([mdmSetup safeServerPassword]);
    XCTAssertTrue([mdmSetup safeRestoreEnable]);
    XCTAssertNil([mdmSetup safeRestoreId]);
    XCTAssertNil([mdmSetup safePasswordPattern]);
    XCTAssertNil([mdmSetup safePasswordMessage]);
    XCTAssertNil([mdmSetup webHosts]);
}

- (void)testSafeBackupDisable {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_DISABLE_BACKUPS };
    id objectsCompanyMdm[] = { @"1" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertTrue([mdmSetup isSafeBackupDisable]);
    XCTAssertFalse([mdmSetup isSafeBackupForce]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupServerPreset]);
    
    XCTAssertTrue([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
    XCTAssertFalse([mdmSetup isSafeRestoreServerPreset]);
}

- (void)testSafeBackupEnable {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_DISABLE_BACKUPS };
    id objectsCompanyMdm[] = { @"0" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertFalse([mdmSetup isSafeBackupForce]);
    XCTAssertFalse([mdmSetup isSafeBackupServerPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);
    
    XCTAssertFalse([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertFalse([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testKeepMessageDays {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_KEEP_MESSAGE_DAYS };
    NSNumber *keep_message_days = [[NSNumber alloc] initWithInt:10];
    id objectsCompanyMdm[] = { keep_message_days };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertEqual(keep_message_days, [mdmSetup keepMessagesDays]);
}

- (void)testBackupForce {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_DISABLE_BACKUPS, MDM_KEY_SAFE_ENABLE };
    id objectsCompanyMdm[] = { @"0", [[NSNumber alloc] initWithInt:1] };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertTrue([mdmSetup isSafeBackupForce]);
    XCTAssertFalse([mdmSetup isSafeBackupServerPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);
    
    XCTAssertFalse([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertFalse([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testBackupWithServerAndPassword {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_DISABLE_BACKUPS, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_PASSWORD };
    id objectsCompanyMdm[] = { @"0", @"https://example.com", @"password" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertFalse([mdmSetup isSafeBackupForce]);
    XCTAssertTrue([mdmSetup isSafeBackupServerPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);
    
    XCTAssertFalse([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertTrue([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testBackupForceWithServerAndPassword {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_DISABLE_BACKUPS, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_PASSWORD };
    id objectsCompanyMdm[] = { @"0", [[NSNumber alloc] initWithInt:1], @"https://example.com", @"password" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertTrue([mdmSetup isSafeBackupForce]);
    XCTAssertTrue([mdmSetup isSafeBackupServerPreset]);
    XCTAssertTrue([mdmSetup isSafeBackupPasswordPreset]);
    
    XCTAssertFalse([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertTrue([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testRestoreDisable {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_SAFE_RESTORE_ENABLE };
    id objectsCompanyMdm[] = { @"0" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertFalse([mdmSetup isSafeBackupForce]);
    XCTAssertFalse([mdmSetup isSafeBackupServerPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);
    
    XCTAssertTrue([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertFalse([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testRestoreEnable {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_SAFE_RESTORE_ENABLE };
    id objectsCompanyMdm[] = { @"1" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertFalse([mdmSetup isSafeBackupForce]);
    XCTAssertFalse([mdmSetup isSafeBackupServerPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);
    
    XCTAssertFalse([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertFalse([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testRestoreEnableWithServerAndPassword {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_PASSWORD,  MDM_KEY_SAFE_RESTORE_ENABLE };
    id objectsCompanyMdm[] = { @"https://example.com", @"password", @"1" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertFalse([mdmSetup isSafeBackupForce]);
    XCTAssertTrue([mdmSetup isSafeBackupServerPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);
    
    XCTAssertFalse([mdmSetup isSafeRestoreDisable]);
    XCTAssertFalse([mdmSetup isSafeRestoreForce]);
    XCTAssertTrue([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertFalse([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testRestoreForceWithServerAndPassword {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    id keysCompanyMdm[] = { MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_PASSWORD,  MDM_KEY_SAFE_RESTORE_ENABLE, MDM_KEY_SAFE_RESTORE_ID };
    id objectsCompanyMdm[] = { @"https://example.com", @"password", @"1", @"EINSZWEI" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    
    XCTAssertFalse([mdmSetup isSafeBackupDisable]);
    XCTAssertFalse([mdmSetup isSafeBackupForce]);
    XCTAssertTrue([mdmSetup isSafeBackupServerPreset]);
    XCTAssertFalse([mdmSetup isSafeBackupPasswordPreset]);

    XCTAssertFalse([mdmSetup isSafeRestoreDisable]);
    XCTAssertTrue([mdmSetup isSafeRestoreForce]);
    XCTAssertTrue([mdmSetup isSafeRestoreServerPreset]);
    XCTAssertTrue([mdmSetup isSafeRestorePasswordPreset]);
}

- (void)testLoadDisabledIDCreationValues {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    [self setMdm:[self getAllMdmParameters:NO] threemaMdm:nil];

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup loadIDCreationValues];
    
    [self setMdm:nil threemaMdm:nil];

    [mdmSetup loadIDCreationValues];
    
    [verifyCount(_mockMyIdentityStore, times(2)) setFirstName:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setLastName:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setCsi:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setCategory:anything()];
}

- (void)testLoadEmptyIDCreationValues {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    [self setMdm:[self getAllMdmParameters:NO] threemaMdm:nil];

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup loadIDCreationValues];
    
    id keysCompanyMdm[] = { MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_CATEGORY };
    id objectsCompanyMdm[] = { @"", @"", @"", @"" };
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    
    [self setMdm:companyMdm threemaMdm:nil];

    [mdmSetup loadIDCreationValues];
    
    [verifyCount(_mockMyIdentityStore, times(2)) setFirstName:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setLastName:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setCsi:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setCategory:anything()];
}

- (void)testReplaceWithEmptyIDCreationValues {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM
    [self setMdm:[self getAllMdmParameters:YES] threemaMdm:nil];

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup loadIDCreationValues];
        
    [self setEmptyMDM];
    [mdmSetup loadIDCreationValues];
    
    [verifyCount(_mockMyIdentityStore, times(2)) setFirstName:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setLastName:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setCsi:anything()];
    [verifyCount(_mockMyIdentityStore, times(2)) setCategory:anything()];
}


- (void)testThreemaMDMSupportDescriptionString {
    NSDictionary *workData = @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:nil threemaMdm:workData];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    XCTAssertEqualObjects([mdmSetup supportDescriptionString], @"m");
}

- (void)testBothMDMSupportDescriptionString {
    NSDictionary *workData = @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:workData threemaMdm:workData];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    XCTAssertEqualObjects([mdmSetup supportDescriptionString], @"me");
}

- (void)testSystemMDMSupportDescriptionString {
    NSDictionary *workData = @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:[self getAllMdmParameters:YES]};
    [self setMdm:workData threemaMdm:nil];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    XCTAssertEqualObjects([mdmSetup supportDescriptionString], @"e");
}

- (void)testEmptySupportDescriptionString {
    NSDictionary *threemaWorkData = @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:@{}};
    NSDictionary *companyWorkData = @{};
    [self setMdm:companyWorkData threemaMdm:threemaWorkData];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    XCTAssertNil([mdmSetup supportDescriptionString]);
}

- (void)testEmptySupportDescriptionString2 {
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    XCTAssertNil([mdmSetup supportDescriptionString]);
}

- (void)testApplyDiscardInThreemaMdmWithCompanyMdm {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM and NO "old" Threema-MDM
    id keysCompanyMdm[] = { MDM_KEY_ID_BACKUP, MDM_KEY_SAFE_PASSWORD, MDM_KEY_ID_BACKUP_PASSWORD};
    id objectsCompanyMdm[] = { @"XXXX-XXXX-...", @"12345678", @"12345678"};
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    // "new" Threema-MDM (override)
    id keysMdm[] = {MDM_KEY_ID_BACKUP, MDM_KEY_ID_BACKUP_PASSWORD, MDM_KEY_SAFE_PASSWORD};
    id objectsMdm[] = { @"YYYY-YYYY-...", @"87654321", @"87654321"};
    NSUInteger countMdm = sizeof(objectsMdm) / sizeof(id);
    NSDictionary *mdm = [NSDictionary dictionaryWithObjects:objectsMdm forKeys:keysMdm count:countMdm];

    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:mdm}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    XCTAssertTrue([mdmSetup hasIDBackup]);
    
    XCTAssertEqual(@"XXXX-XXXX-...", [mdmSetup idBackup]);
    XCTAssertEqual(@"12345678", [mdmSetup safePassword]);
    XCTAssertEqual(@"12345678", [mdmSetup idBackupPassword]);
}

- (void)testDiscardInThreemaMdmWithCompanyMdm {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
    
    // Company-MDM and NO "old" Threema-MDM
    id keysCompanyMdm[] = { MDM_KEY_ID_BACKUP, MDM_KEY_SAFE_PASSWORD, MDM_KEY_ID_BACKUP_PASSWORD, MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD};
    id objectsCompanyMdm[] = { @"XXXX-XXXX-...", @"12345678", @"12345678", @"new-tester", @"new-test1234"};
    NSUInteger countCompanyMdm = sizeof(objectsCompanyMdm) / sizeof(id);
    NSDictionary *companyMdm = [NSDictionary dictionaryWithObjects:objectsCompanyMdm forKeys:keysCompanyMdm count:countCompanyMdm];
    [self setMdm:companyMdm threemaMdm:nil];
    
    // "new" Threema-MDM (override)
    id keysMdm[] = { };
    id objectsMdm[] = { };
    NSUInteger countMdm = sizeof(objectsMdm) / sizeof(id);
    NSDictionary *mdm = [NSDictionary dictionaryWithObjects:objectsMdm forKeys:keysMdm count:countMdm];

    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:mdm}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    [verify(_mockLicenseStore) setLicenseUsername:@"new-tester"];
    [verify(_mockLicenseStore) setLicensePassword:@"new-test1234"];
    
    XCTAssertTrue([mdmSetup hasIDBackup]);
    
    XCTAssertEqual(@"XXXX-XXXX-...", [mdmSetup idBackup]);
    XCTAssertEqual(@"12345678", [mdmSetup safePassword]);
    XCTAssertEqual(@"12345678", [mdmSetup idBackupPassword]);
}

- (void)testApplyDiscardInThreemaMdmWithoutCompanyMdm {
    [given([_mockLicenseStore getRequiresLicenseKey]) willReturnBool:YES];
        
    // "new" Threema-MDM (override)
    id keysMdm[] = {MDM_KEY_ID_BACKUP, MDM_KEY_ID_BACKUP_PASSWORD, MDM_KEY_SAFE_PASSWORD, MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD};
    id objectsMdm[] = { @"YYYY-YYYY-...", @"87654321", @"87654321", @"mdm@mdm.ch", @"87654321"};
    NSUInteger countMdm = sizeof(objectsMdm) / sizeof(id);
    NSDictionary *mdm = [NSDictionary dictionaryWithObjects:objectsMdm forKeys:keysMdm count:countMdm];

    NSDictionary *workData = @{MDM_KEY_THREEMA_CONFIGURATION: @{MDM_KEY_THREEMA_OVERRIDE:@true,MDM_KEY_THREEMA_PARAMS:mdm}};
   
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    [mdmSetup applyThreemaMdm:workData sendForce:NO];
    
    XCTAssertFalse([mdmSetup hasIDBackup]);
    
    XCTAssertNil([mdmSetup idBackup]);
    XCTAssertNil([mdmSetup safePassword]);
    XCTAssertNil([mdmSetup idBackupPassword]);
    XCTAssertNil([_mockLicenseStore licenseUsername]);
    XCTAssertNil([_mockLicenseStore licensePassword]);
}

- (NSDictionary*)getAllMdmParameters:(BOOL)isThreemaMdm  {
    id keysMdm[] = { MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_NICKNAME, MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_CATEGORY, MDM_KEY_LINKED_EMAIL, MDM_KEY_LINKED_PHONE, MDM_KEY_CONTACT_SYNC, MDM_KEY_READONLY_PROFILE, MDM_KEY_BLOCK_UNKNOWN, MDM_KEY_HIDE_INACTIVE_IDS, MDM_KEY_DISABLE_SAVE_TO_GALLERY, MDM_KEY_DISABLE_ADD_CONTACT, MDM_KEY_DISABLE_EXPORT, MDM_KEY_DISABLE_BACKUPS, MDM_KEY_DISABLE_ID_EXPORT, MDM_KEY_DISABLE_SYSTEM_BACKUPS, MDM_KEY_DISABLE_MESSAGE_PREVIEW, MDM_KEY_DISABLE_SEND_PROFILE_PICTURE, MDM_KEY_DISABLE_CALLS, MDM_KEY_DISABLE_VIDEO_CALLS,  MDM_KEY_DISABLE_GROUP_CALLS, MDM_KEY_SKIP_WIZARD, MDM_KEY_DISABLE_CREATE_GROUP, MDM_KEY_DISABLE_WEB, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_SERVER_USERNAME, MDM_KEY_SAFE_SERVER_PASSWORD, MDM_KEY_SAFE_RESTORE_ENABLE, MDM_KEY_SAFE_RESTORE_ID, MDM_KEY_SAFE_PASSWORD_PATTERN, MDM_KEY_SAFE_PASSWORD_MESSAGE, MDM_KEY_WEB_HOSTS, MDM_KEY_DISABLE_SHARE_MEDIA, MDM_KEY_DISABLE_WORK_DIRECTORY, MDM_KEY_KEEP_MESSAGE_DAYS};
    id objectsMdm[] = { @"tester", @"test1234", @"Eieri", @"Heiri", @"Heirassa", @"customer-id", @"category", @"linked@email.com", @"111", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", @"1", _yes, @"http://test.com", @"server-user", @"server-password", @"0", @"ECHOECHO", @"^[0-9]{1,15}$", @"Wrong-password-pattern", @"threema.ch", @"1", @"1", @"7"};
    
    NSUInteger countMdm = sizeof(objectsMdm) / sizeof(id);
    NSMutableDictionary *mdm = [NSMutableDictionary dictionaryWithObjects:objectsMdm forKeys:keysMdm count:countMdm];

    // add parameter if not Threema-MDM
    if (!isThreemaMdm) {
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"87654321", MDM_KEY_SAFE_PASSWORD, nil];
        [mdm addEntriesFromDictionary:dic];
    }

    return mdm;
}

@end
