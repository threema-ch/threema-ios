//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "NewScannedContactViewController.h"
#import "Contact.h"
#import "ContactStore.h"
#import "StatusNavigationBar.h"
#import "EditContactViewController.h"
#import "EntityManager.h"
#import "AvatarMaker.h"
#import "AppDelegate.h"
#import "UIDefines.h"
#import "ModalPresenter.h"
#import "BundleUtil.h"
#import "GatewayAvatarMaker.h"
#import "NSString+Hex.h"
#import "FeatureMask.h"
#import "ServerConnector.h"
#import "BundleUtil.h"
#import "Threema-Swift.h"
#import "TrustedContacts.h"

@interface NewScannedContactViewController ()
@end

@implementation NewScannedContactViewController {
    CNContactStore *cnAddressBook;
    Contact *dummyContact;
    EntityManager *tempEntityManager;
    PublicKeyView *publicKeyView;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        cnAddressBook = [CNContactStore new];
        
        /* make a dummy contact (not Core Data managed) that we can pass to EditNameViewController */
        tempEntityManager = [[EntityManager alloc] init];
        dummyContact = tempEntityManager.entityCreator.contact;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.contactImage.layer.masksToBounds = YES;
    self.contactImage.contentMode = UIViewContentModeScaleAspectFill;
    self.contactImage.layer.cornerRadius = self.contactImage.frame.size.width/2;
    
    if (dummyContact.isGatewayId) {
        self.editNameButton.hidden = YES;
        self.linkToContactCell.hidden = YES;
        self.threemaCallCell.hidden = YES;
        self.threemaTypeIcon.hidden = true;
    } else {        
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedHeaderView)];
        [self.contactImage addGestureRecognizer:tapRecognizer];
        _threemaTypeIcon.image = [Utils threemaTypeIcon];
        if (!is64Bit) {
            self.threemaCallCell.hidden = YES;
        }
    }

    [self setupColors];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleTitle3];
    CGFloat size = fontDescriptor.pointSize;
    _nameLabel.font = [UIFont boldSystemFontOfSize:size];
}

- (void)setupColors {
    [_nameLabel setTextColor:[Colors fontNormal]];
    _nameLabel.shadowColor = nil;
    
    UIImage *editNameImage = [_editNameButton.imageView.image imageWithTint:[Colors main]];
    [_editNameButton setImage:editNameImage forState:UIControlStateNormal];
    _editNameButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"edit_contact"];
    
    if (@available(iOS 11.0, *)) {
        _contactImage.accessibilityIgnoresInvertColors = true;
        _threemaTypeIcon.accessibilityIgnoresInvertColors = true;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [publicKeyView close];
}

- (void)setIdentity:(NSString *)identity {
    _identity = identity;
    
    dummyContact.identity = identity;
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

- (void)updateView {
    
    self.sendMessageLabel.text = [BundleUtil localizedStringForKey:@"send_message"];
    self.threemaCallLabel.text = [BundleUtil localizedStringForKey:@"call_voip_not_supported_title"];
    
    self.identityLabel.text = self.identity;
    self.publicKeyCell.textLabel.text = [BundleUtil localizedStringForKey:@"public_key"];
    
    // check if this is a trusted contact (like *THREEMA)
    if ([TrustedContacts isTrustedContactWithIdentity:self.identity publicKey:_publicKey]) {
        _verificationLevel = kVerificationLevelFullyVerified;
    }
    
    dummyContact.verificationLevel = [NSNumber numberWithInt:_verificationLevel];
    self.verificationLevelCell.contact = dummyContact;
    
    if ([LicenseStore requiresLicenseKey] == true) {
        self.threemaTypeIcon.hidden = [self.type isEqualToNumber:@1];
    } else {
        self.threemaTypeIcon.hidden = ![self.type isEqualToNumber:@1];
    }
    
    [self.contactImage setImage:[[AvatarMaker sharedAvatarMaker] avatarForContact:dummyContact size:self.contactImage.frame.size.width masked:NO]];
    
    if (self.cnContactId != nil) {
        if (cnAddressBook != nil) {
            [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (granted == YES) {
                    NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[self.cnContactId]];
                    NSError *error;
                    NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                    if (error) {
                        NSLog(@"error fetching contacts %@", error);
                    } else {
                        CNContact *person = cnContacts.firstObject;
                        if (person != nil) {
                            self.linkedContactNameLabel.text = [CNContactFormatter stringFromContact:person style:CNContactFormatterStyleFullName];
                            
                            dummyContact.firstName = person.givenName;
                            dummyContact.lastName = person.familyName;
                        }
                    }
                }
            }];
        }
        self.editNameButton.enabled = NO;
        self.contactImage.userInteractionEnabled = NO;
    } else {
        self.linkedContactNameLabel.text = [BundleUtil localizedStringForKey:@"(none)"];
        self.editNameButton.enabled = YES;
        self.contactImage.userInteractionEnabled = YES;
    }
    
    self.nameLabel.text = dummyContact.displayName;
    
    if (dummyContact.isGatewayId) {
        [[GatewayAvatarMaker gatewayAvatarMaker] loadAvatarForId:dummyContact.identity onCompletion:^(UIImage *image) {
            [self.contactImage setImage:image];
        } onError:^(NSError *error) {
        }];
    }
    
    publicKeyView = [[PublicKeyView alloc] initWithIdentity:_identity publicKey:_publicKey];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"EditName"]) {
        EditContactViewController *editVc = (EditContactViewController*)segue.destinationViewController;
        if ([dummyContact.firstName isEqual:self.identity])
            dummyContact.firstName = nil;
        editVc.contact = dummyContact;
    }
}


#pragma mark - Private functions

- (Contact *)saveContact {

    NSString *dummyFirstName = dummyContact.firstName;
    NSString *dummyLastName = dummyContact.lastName;
    NSData *dummyImageData = dummyContact.imageData;
    // delete dummy contact first, otherwise it will be found when adding contact
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        Contact *contact = (Contact *)[entityManager.entityFetcher getManagedObjectById:dummyContact.objectID];
        [[entityManager entityDestroyer] deleteObjectWithObject:contact];
    }];
    
    Contact *savedContact = [[ContactStore sharedContactStore] addContactWithIdentity:self.identity publicKey:self.publicKey cnContactId:self.cnContactId verificationLevel:_verificationLevel state:_state type:_type featureMask:self.featureMask alerts:YES];
    
    if (savedContact == nil) {
        return savedContact;
    }
    
    if (savedContact.isGatewayId) {
        [[GatewayAvatarMaker gatewayAvatarMaker] loadAndSaveAvatarForId:savedContact.identity];
    }
    
    if (self.cnContactId == nil) {
        [entityManager performSyncBlockAndSafe:^{
            Contact *contact = (Contact *)[entityManager.entityFetcher getManagedObjectById:savedContact.objectID];
            
            if (dummyFirstName && ![dummyFirstName isEqual:self.identity]) {
                contact.firstName = dummyFirstName;
            }
            
            if (dummyLastName) {
                contact.lastName = dummyLastName;
            }
            
            if (dummyImageData) {
                contact.imageData = dummyImageData;
            }
        }];
    }
    
    return savedContact;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (selectedCell == self.linkToContactCell) {
        CNContactPickerViewController *picker = [[CNContactPickerViewController alloc] init];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
    else if (selectedCell == self.sendMessageCell) {
        __block Contact *contact = [self saveContact];
        [self dismissViewControllerAnimated:YES completion:^{
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys: contact, kKeyContact, [NSNumber numberWithBool:YES], kKeyForceCompose, nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
        }];
    }
    else if (selectedCell == self.threemaCallCell) {
        __block Contact *contact = [self saveContact];
        [self dismissViewControllerAnimated:YES completion:^{
            NSInteger state = [[VoIPCallStateManager shared] currentCallState];
            if (state == CallStateIdle) {
                [FeatureMask checkFeatureMask:FEATURE_MASK_VOIP forContacts:[NSSet setWithObjects:contact, nil] onCompletion:^(NSArray *unsupportedContacts) {
                    if (unsupportedContacts.count == 0) {
                        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                        if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
                            VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:ActionCall contact:contact callId:nil completion:nil];
                            [[VoIPCallStateManager shared] processUserAction:action];
                        } else {
                            // Alert no internet connection
                            NSString *title = NSLocalizedString(@"cannot_connect_title", nil);
                            NSString *message = NSLocalizedString(@"cannot_connect_message", nil);
                            [UIAlertTemplate showAlertWithOwner:self title:title message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
                                [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL expired) {
                                }];
                            }];
                        }
                    } else {
                        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                        [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"call_voip_not_supported_title", nil) message:NSLocalizedString(@"call_voip_not_supported_text", nil) actionOk:nil];
                    }
                }];
            } else {
                [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
            }
        }];
    } else if (selectedCell == self.publicKeyCell) {
        [publicKeyView show];
        [tableView deselectRowAtIndexPath:indexPath animated:true];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        [Colors updateTableViewCellBackground:cell];
        [Colors setTextColor:[Colors main] inView:cell.contentView];
    } else {
        [Colors updateTableViewCell:cell];
    }
}

- (IBAction)save:(id)sender {
    [self saveContact];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)editContact:(id)sender {
    [self tappedHeaderView];
}

- (void)sendMessage {
    [self saveContact];
    [self dismissViewControllerAnimated:YES completion:^{
        // open chat of the contact
    }];
}

#pragma mark - People picker delegate

-(void) contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact{
    self.cnContactId = contact.identifier;
    [self updateView];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty  {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
    self.cnContactId = nil;
    [self updateView];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [tempEntityManager rollback];
}

- (void)tappedHeaderView {
    if (self.cnContactId != nil) {
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[self.cnContactId]];
                NSError *error;
                NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                if (error) {
                    NSLog(@"error fetching contacts %@", error);
                } else {
                    CNContact *person = cnContacts.firstObject;
                    if (person != nil) {
                        CNContactViewController *personVc = [CNContactViewController viewControllerForContact:person];
                        personVc.allowsActions = NO;
                        personVc.allowsEditing = YES;
                        [self.navigationController pushViewController:personVc animated:YES];
                    }
                }
            }
        }];
    } else {
        EditContactViewController *editVc = [self.storyboard instantiateViewControllerWithIdentifier:@"EditContactViewController"];
        editVc.contact = dummyContact;
        [self.navigationController pushViewController:editVc animated:YES];
    }
}

@end
