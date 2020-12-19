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

#import <Contacts/Contacts.h>
#import <QuartzCore/QuartzCore.h>
#import <MessageUI/MessageUI.h>

#import "ContactDetailsViewController.h"
#import "LinkedContactCell.h"
#import "KeyFingerprintCell.h"
#import "VerificationLevelCell.h"
#import "BlockContactCell.h"
#import "Contact.h"
#import "ContactStore.h"
#import "ConversationsViewController.h"
#import "StatusNavigationBar.h"
#import "ScanIdentityController.h"
#import "CryptoUtils.h"
#import "UIDefines.h"
#import "EditContactViewController.h"
#import "ConversationExporter.h"
#import "EntityManager.h"
#import "AvatarMaker.h"
#import "FullscreenImageViewController.h"
#import "ContactGroupMembershipViewController.h"
#import "ModalNavigationController.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "ContactPhotoSender.h"
#import "FeatureMask.h"
#import "ServerConnector.h"
#import "Utils.h"
#import "Threema-Swift.h"
#import "MDMSetup.h"
#import "CopyLabel.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"


#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface ContactDetailsViewController ()

@property NSInteger indexId;
@property NSInteger indexNickname;
@property NSInteger indexLinkedContact;
@property NSInteger indexGroupMembership;
@property NSInteger indexVerificationLevel;
@property NSInteger indexFingerprint;

@property NSInteger numberOfRowsInSection0;

@property BOOL didHideTabBar;

@property NSMutableArray *callNumbers;

@end

@implementation ContactDetailsViewController {
    CNContactStore *cnAddressBook;
    CNContact *cnContact;
    BOOL cnContactViewShowing;
    
    BOOL canExportConversation;
    
    Conversation *conversation;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (![ScanIdentityController canScan])
        self.navigationItem.rightBarButtonItem = nil;
    
    self.navigationController.interactivePopGestureRecognizer.enabled  = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showProfilePictureChanged:) name:kNotificationShowProfilePictureChanged object:nil];
    
    cnAddressBook = [CNContactStore new];
        
    UITapGestureRecognizer *disclosureTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedHeaderView)];
    [_disclosureButton addGestureRecognizer:disclosureTapRecognizer];
    _disclosureButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"edit_contact"];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedImage)];
    [_imageView addGestureRecognizer:tapRecognizer];
    
    _threemaTypeIcon.image = [Utils threemaTypeIcon];
    
    [self setupColors];
}

- (void)setupColors {
    [_nameLabel setTextColor:[Colors fontNormal]];
    _nameLabel.shadowColor = nil;
    
    [_companyNameLabel setTextColor:[Colors fontLight]];
    _companyNameLabel.shadowColor = nil;
    
    UIImage *disclosureImage = [self.disclosureButton.imageView.image imageWithTint:[Colors main]];
    [self.disclosureButton setImage:disclosureImage forState:UIControlStateNormal];

    if (@available(iOS 11.0, *)) {
        _imageView.accessibilityIgnoresInvertColors = true;
        _threemaTypeIcon.accessibilityIgnoresInvertColors = true;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    /* did we come back from ABPersonView? If so, the contact data may have changed,
     and we need to update */
    if (cnContactViewShowing) {
        cnContactViewShowing = NO;
        [[ContactStore sharedContactStore] updateContact:self.contact];
        [(StatusNavigationBar *)self.navigationController.navigationBar showOrHideStatusView];
         [Colors updateNavigationBar:self.navigationController.navigationBar];
    }
        
    self.view.alpha = 1.0;
    
    [self updateView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.navigationController.navigationBarHidden) {
        [self.navigationController setNavigationBarHidden:NO];
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleTitle3];
    CGFloat size = fontDescriptor.pointSize;
    _nameLabel.font = [UIFont boldSystemFontOfSize:size];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"EditName"]) {
        EditContactViewController *editVc = (EditContactViewController*)segue.destinationViewController;
        editVc.contact = self.contact;
    }
    else if ([segue.identifier isEqualToString:@"ShowPushSetting"]) {
        NotificationSettingViewController *notificationSettingViewController = (NotificationSettingViewController *)segue.destinationViewController;
        notificationSettingViewController.identity = self.contact.identity;
        notificationSettingViewController.isGroup = NO;
        notificationSettingViewController.conversation = conversation;
    }
}

- (void)updateView {
    _scanQrCodeBarButtonItem.accessibilityLabel = [BundleUtil localizedStringForKey:@"scan_identity"];
    
    NSString *name = self.contact.displayName;
    
    self.navigationItem.title = name;
    _nameLabel.text = name;
    _headerView.accessibilityLabel = _nameLabel.text;
    
    _imageView.image = [[AvatarMaker sharedAvatarMaker] avatarForContact:self.contact size:_imageView.frame.size.width masked:NO];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.layer.masksToBounds = YES;
    _imageView.layer.cornerRadius = _imageView.bounds.size.width / 2;
    
    _threemaTypeIcon.hidden = [Utils hideThreemaTypeIconForContact:self.contact];
    
    self.companyNameLabel.text = @"";
    cnContact = nil;
    if (self.contact.cnContactId != nil) {
        if (cnAddressBook != nil) {
            
            [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (granted == YES) {
                    NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[self.contact.cnContactId]];
                    NSError *error;
                    NSMutableArray *keys = [[NSMutableArray alloc] initWithArray:kCNContactKeys];
                    [keys addObject:[CNContactViewController descriptorForRequiredKeys]];
                    NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:keys error:&error];
                    if (error) {
                        NSLog(@"error fetching contacts %@", error);
                    } else {
                        cnContact = cnContacts.firstObject;
                        [self getPhoneCallNumbers];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.companyNameLabel.text = cnContact.organizationName;
                            [self.tableView reloadData];
                        });
                    }
                }
            }];
        }
    }
    CGFloat headerHeight = 0;
    if (self.companyNameLabel.text.length == 0) {
        self.companyNameLabel.hidden = true;
        headerHeight = 275.0;
    } else {
        self.companyNameLabel.hidden = false;
        headerHeight = 300.0;
    }
    _headerView.frame = CGRectMake(_headerView.frame.origin.x, _headerView.frame.origin.y, _headerView.frame.size.width, headerHeight);
    
    /* show e-mail conversation button only if there is a conversation for this contact */
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    EntityManager *entityManager = [[EntityManager alloc] init];
    conversation = [entityManager.entityFetcher conversationForContact: self.contact];
    if (conversation == nil || [mdmSetup disableExport])
        canExportConversation = NO;
    else
        canExportConversation = YES;
    
    NSInteger i = 0;
    _indexId = i++;
    if (self.contact.publicNickname.length > 0 && ![self.contact.publicNickname isEqualToString:self.contact.identity]) {
        _indexNickname = i++;
    } else {
        _indexNickname = -1;
    }
    
    if (_contact.isGatewayId) {
        _indexLinkedContact = -1;
        _disclosureButton.hidden = YES;
    } else {
        _indexLinkedContact = i++;
        _disclosureButton.hidden = NO;
    }
    
    _indexGroupMembership = i++;
    _indexVerificationLevel = i++;
    _indexFingerprint = i++;
    
    _numberOfRowsInSection0 = _indexFingerprint + 1;
    
    if (_didHideTabBar) {
        [self.tabBarController.tabBar setHidden:NO];
        _didHideTabBar = NO;
    }
    
    [self.tableView reloadData];
}

- (IBAction)sendMessageAction:(id)sender {
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          self.contact, kKeyContact,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
}

- (IBAction)scanIdentityAction:(id)sender; {
    ScanIdentityController *scanController = [[ScanIdentityController alloc] init];
    scanController.containingViewController = self;
    scanController.expectedIdentity = self.contact.identity;
    scanController.popupScanResults = NO;
    [scanController startScan];
}

- (void)conversationAction:(id)sender {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedString(@"include_media_title", nil), kExportConversationMediaSizeLimit] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"include_media", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        ConversationExporter *exporter = [ConversationExporter exporterOnViewController: self];
        [exporter exportConversationForContact:self.contact withMedia: YES];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"without_media", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        ConversationExporter *exporter = [ConversationExporter exporterOnViewController: self];
        [exporter exportConversationForContact:self.contact withMedia: NO];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1] animated:YES];
    }]];
    
    if ([sender isKindOfClass:[UIView class]]) {
        UIView *senderView = (UIView *)sender;
        actionSheet.popoverPresentationController.sourceRect = senderView.frame;
        actionSheet.popoverPresentationController.sourceView = self.view;
    }
    
    [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:actionSheet animated:YES completion:nil];
}

- (void)tappedImage {
    if ((_contact.contactImage && [UserSettings sharedUserSettings].showProfilePictures) || _contact.imageData) {
        UIImage *image = nil;
        
        if (_contact.contactImage && [UserSettings sharedUserSettings].showProfilePictures) {
            image = [UIImage imageWithData:_contact.contactImage.data];
        } else {
            image = [UIImage imageWithData:_contact.imageData];
        }
        
        FullscreenImageViewController *imageController = [FullscreenImageViewController controllerForImage:image];
        
        if (SYSTEM_IS_IPAD) {
            ModalNavigationController *nav = [[ModalNavigationController alloc] initWithRootViewController:imageController];
            nav.showDoneButton = YES;
            nav.showFullScreenOnIPad = YES;
            
            [self presentViewController:nav animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:imageController animated:YES];
        }
    } else {
        [self tappedHeaderView];
    }
}

- (void)tappedHeaderView {
    if (self.contact.isGatewayId) {
        return;
    }
    
    if (cnContact != nil) {
        CNContactViewController *personVc = [CNContactViewController viewControllerForContact:cnContact];
        personVc.allowsActions = YES;
        personVc.allowsEditing = YES;
        cnContactViewShowing = YES;
        
        if (self.tabBarController.tabBar.hidden == NO) {
            _didHideTabBar = YES;
            [self.tabBarController.tabBar setHidden:YES];
        }
        [(StatusNavigationBar *)self.navigationController.navigationBar hideStatusView];
        self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
        [self.navigationController pushViewController:personVc animated:YES];
    } else {
        [self showEditContactVC];
    }
}

- (void)startPofilePictureAction {
    ContactPhotoSender *sender = [[ContactPhotoSender alloc] init];
    [sender startWithImageToMember:_contact onCompletion:^{
        [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"my_profilepicture", nil) message:NSLocalizedString(@"contact_send_profilepicture_success", nil) actionOk:nil];
    } onError:^(NSError *err) {
        [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"my_profilepicture", nil) message:NSLocalizedString(@"contact_send_profilepicture_error", nil) actionOk:nil];
    }];

    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (void)startThreemaCallAction {
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (state == CallStateIdle) {
        [FeatureMask checkFeatureMask:FEATURE_MASK_VOIP forContacts:[NSSet setWithObjects:_contact, nil] onCompletion:^(NSArray *unsupportedContacts) {
            if (unsupportedContacts.count == 0) {
                [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                [self startVoipCall];
            } else {
                [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"call_voip_not_supported_title", nil) message:NSLocalizedString(@"call_voip_not_supported_text", nil) actionOk:nil];
            }
        }];
    } else {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    }
}

- (void)startPhoneCallAction {
    NSIndexPath *selectedIndexPath = self.tableView.indexPathForSelectedRow;
     [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    if (_contact.cnContactId != nil) {
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[_contact.cnContactId]];
                NSError *error;
                NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                if (error) {
                    NSLog(@"error fetching contacts %@", error);
                } else {
                    CNContact *person = cnContacts.firstObject;
                    if (person != nil) {
                        /* get all phone numbers and present in Action Sheet */
                        UIAlertController *callActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                        _callNumbers = [NSMutableArray array];
                        
                        for (CNLabeledValue *phone in person.phoneNumbers) {
                            NSString *label = phone.label;
                            NSString *localizedLabel = [CNLabeledValue localizedStringForLabel:label];
                            NSString *number = [phone.value stringValue];
                            
                            if ([_callNumbers containsObject:number])
                                continue;
                            
                            [callActionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@: %@", localizedLabel, number] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                NSUInteger index = [callActionSheet.actions indexOfObject:action];
                                NSString *number = _callNumbers[index];
                                [[UIApplication sharedApplication] openURL:[self makeTelUrlForPhone:number] options:@{} completionHandler:nil];
                            }]];
                            [_callNumbers addObject:number];
                        }
                        
                        //        DDLogVerbose(@"Phone numbers: %@", _callNumbers);
                        
                        [callActionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
                        }]];
                        
                        if (_callNumbers.count == 0) {
                            [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"call_voip_not_supported_title", nil) message:NSLocalizedString(@"call_voip_not_supported_text", nil) actionOk:nil];
                        } else if (_callNumbers.count == 1) {
                            [[UIApplication sharedApplication] openURL:[self makeTelUrlForPhone:_callNumbers[0]] options:@{} completionHandler:nil];
                        } else if (_callNumbers.count > 1) {
                            
                            if (SYSTEM_IS_IPAD) {
                                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:selectedIndexPath];
                                callActionSheet.popoverPresentationController.sourceView = cell.contentView;
                                callActionSheet.popoverPresentationController.sourceRect = cell.contentView.bounds;
                            }
                            [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:callActionSheet animated:YES completion:nil];
                        }
                    }
                }
            }
        }];
    }
}

- (void)startVoipCall {
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    
    if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
        VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:ActionCall contact:_contact completion:nil];
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
}

- (NSURL*)makeTelUrlForPhone:(NSString*)phoneNumber {
    return [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", [phoneNumber stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]]];
}

- (void)getPhoneCallNumbers {
    if (cnContact != nil) {
        _callNumbers = nil;
        _callNumbers = [NSMutableArray array];

        for (CNLabeledValue *phone in cnContact.phoneNumbers) {
            NSString *number = [phone.value stringValue];
            if ([_callNumbers containsObject:number])
                continue;

            [_callNumbers addObject:number];
        }
    }
}

- (BOOL)showPhoneCallButton {
    if (cnContact != nil) {
        if (_callNumbers.count == 0) {
            return NO;
        }
        return YES;
    }
    return NO;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!_contact.isGatewayId && !_contact.isEchoEcho && [UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureContacts) {
        return 4;
    }
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return _numberOfRowsInSection0;
    } else if (section == 1) {
        if (_hideActionButtons) {
            return 0;
        }

        NSInteger numRows = [UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1 ? 2 : 1;
        if ([ScanIdentityController canScan])
            numRows++;
        if (canExportConversation)
            numRows++;
        if (!_contact.isGatewayId && !_contact.isEchoEcho && ([UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureAll || ([UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureContacts && [[UserSettings sharedUserSettings].profilePictureContactList containsObject:_contact.identity])))
            numRows++;
        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton])
            numRows++;
        return numRows;
    } else if (section == 2) {
        if (!_contact.isGatewayId && !_contact.isEchoEcho && [UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureContacts) {
            return 1;
        } else {
            return 2;
        }
    } else {
        return 2;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
            if (indexPath.row == _indexId) {
                UITableViewCell *identityCell = [tableView dequeueReusableCellWithIdentifier:@"IdentityCell"];
                ((UILabel*)[identityCell viewWithTag:100]).text = self.contact.identity;
                ((UILabel*)[identityCell viewWithTag:100]).isAccessibilityElement = false;
                return identityCell;
            } else if (indexPath.row == _indexFingerprint) {
                KeyFingerprintCell *kfc = [tableView dequeueReusableCellWithIdentifier:@"KeyFingerprintCell"];
                kfc.fingerprintLabel.text = [CryptoUtils fingerprintForPublicKey:self.contact.publicKey];
                return kfc;
            } else if (indexPath.row == _indexVerificationLevel) {
                VerificationLevelCell *vlc = [tableView dequeueReusableCellWithIdentifier:@"VerificationLevelCell"];
                vlc.contact = self.contact;
                vlc.accessibilityTraits = UIAccessibilityTraitButton;
                return vlc;
            } else if (indexPath.row == _indexNickname) {
                UITableViewCell *publicNicknameCell = [tableView dequeueReusableCellWithIdentifier:@"PublicNicknameCell"];
                ((UILabel*)[publicNicknameCell viewWithTag:101]).text = self.contact.publicNickname;
                return publicNicknameCell;
            } else if (indexPath.row == _indexGroupMembership) {
                UITableViewCell *groupMembershipCell = [tableView dequeueReusableCellWithIdentifier:@"GroupMembershipCell"];
                ((UILabel*)[groupMembershipCell viewWithTag:102]).text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.contact.groupConversations count]];
                groupMembershipCell.accessibilityTraits = UIAccessibilityTraitButton;
                return groupMembershipCell;
            } else if (indexPath.row == _indexLinkedContact) {
                LinkedContactCell *lcc = [tableView dequeueReusableCellWithIdentifier:@"LinkedContactCell"];
                lcc.accessibilityTraits = UIAccessibilityTraitButton;
                
                if (cnContact != nil) {
                    lcc.displayNameLabel.text = [CNContactFormatter stringFromContact:cnContact style:CNContactFormatterStyleFullName];
                    if (lcc.displayNameLabel.text.length == 0) {
                        if (cnContact.emailAddresses) {
                            if (cnContact.emailAddresses.count > 0) {
                                lcc.displayNameLabel.text = ((CNLabeledValue *)cnContact.emailAddresses.firstObject).value;
                            }
                        }
                    }
                } else {
                    lcc.displayNameLabel.text = [BundleUtil localizedStringForKey:@"(none)"];
                }
                
                return lcc;
            }
            break;
        case 1: {
            NSString *cellIdentifier;
            if (indexPath.row == 0) {
                cellIdentifier = @"SendMessageCell";
            }
            else if (indexPath.row == 1) {
                if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                    cellIdentifier = @"ThreemaCallCell";
                } else {
                    if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                        cellIdentifier = @"PhoneCallCell";
                    }
                    else if (canExportConversation) {
                        cellIdentifier = @"ExportConversationCell";
                    }
                    else if ([ScanIdentityController canScan]) {
                        cellIdentifier = @"ScanIDCell";
                    }
                    else {
                        cellIdentifier = @"SendProfilePictureCell";
                    }
                }
            }
            else if (indexPath.row == 2) {
                if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                    if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                        cellIdentifier = @"PhoneCallCell";
                    }
                    else if (canExportConversation) {
                        cellIdentifier = @"ExportConversationCell";
                    }
                    else if ([ScanIdentityController canScan]) {
                        cellIdentifier = @"ScanIDCell";
                    }
                    else {
                        cellIdentifier = @"SendProfilePictureCell";
                    }
                } else {
                    if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                        if (canExportConversation) {
                            cellIdentifier = @"ExportConversationCell";
                        }
                        else if (canExportConversation && [ScanIdentityController canScan]) {
                            cellIdentifier = @"ScanIDCell";
                        }
                        else {
                            cellIdentifier = @"SendProfilePictureCell";
                        }
                    } else {
                        if (canExportConversation && [ScanIdentityController canScan]) {
                            cellIdentifier = @"ScanIDCell";
                        } else {
                            cellIdentifier = @"SendProfilePictureCell";
                        }
                    }
                }
            } else if (indexPath.row == 3) {
                if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                    if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                        if (canExportConversation) {
                            cellIdentifier = @"ExportConversationCell";
                        }
                        else if ([ScanIdentityController canScan]) {
                            cellIdentifier = @"ScanIDCell";
                        }
                        else {
                            cellIdentifier = @"SendProfilePictureCell";
                        }
                    } else {
                        if (canExportConversation && [ScanIdentityController canScan]) {
                            cellIdentifier = @"ScanIDCell";
                        } else {
                            cellIdentifier = @"SendProfilePictureCell";
                        }
                    }
                } else {
                    if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                        if (canExportConversation && [ScanIdentityController canScan]) {
                            cellIdentifier = @"ScanIDCell";
                        }
                        else {
                            cellIdentifier = @"SendProfilePictureCell";
                        }
                    } else {
                        cellIdentifier = @"SendProfilePictureCell";
                    }
                }
            }
            else if (indexPath.row == 4) {
                if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                    if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                        if (canExportConversation && [ScanIdentityController canScan]) {
                            cellIdentifier = @"ScanIDCell";
                        } else {
                            cellIdentifier = @"SendProfilePictureCell";
                        }
                    } else {
                        cellIdentifier = @"SendProfilePictureCell";
                    }
                } else {
                    if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                        cellIdentifier = @"SendProfilePictureCell";
                    }
                }
            } else if (indexPath.row == 5) {
                cellIdentifier = @"SendProfilePictureCell";
            }
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            return cell;
        }
        case 2: {
            if (!_contact.isGatewayId && !_contact.isEchoEcho && [UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureContacts) {
                ProfilePictureRecipientCell *profilePictureRecipientCell = [tableView dequeueReusableCellWithIdentifier:@"ProfilePictureRecipientCell"];
                profilePictureRecipientCell.identity = self.contact.identity;
                profilePictureRecipientCell.delegate = self;
                return profilePictureRecipientCell;
            } else {
                switch (indexPath.row) {
                    case 0: {
                        UITableViewCell *pushSettingCell = [tableView dequeueReusableCellWithIdentifier:@"PushSettingCell"];
                        pushSettingCell.textLabel.text = NSLocalizedString(@"pushSetting_title", @"");
                        return pushSettingCell;
                    }
                    case 1: {
                        BlockContactCell *bcc = [tableView dequeueReusableCellWithIdentifier:@"BlockCell"];
                        bcc.identity = self.contact.identity;
                        return bcc;
                    }
                }
            }
            break;
        }
        case 3: {
            switch (indexPath.row) {
                case 0: {
                    UITableViewCell *pushSettingCell = [tableView dequeueReusableCellWithIdentifier:@"PushSettingCell"];
                    pushSettingCell.textLabel.text = NSLocalizedString(@"pushSetting_title", @"");
                    return pushSettingCell;
                }
                case 1: {
                    BlockContactCell *bcc = [tableView dequeueReusableCellWithIdentifier:@"BlockCell"];
                    bcc.identity = self.contact.identity;
                    return bcc;
                }
            }
            break;
        }
    }
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2 && !_contact.isGatewayId && !_contact.isEchoEcho && [UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureContacts) {
        if ([[UserSettings sharedUserSettings].profilePictureContactList containsObject:_contact.identity]) {
            return  NSLocalizedString(@"contact_added_to_profilepicture_list", nil);
        } else {
            return  NSLocalizedString(@"contact_removed_from_profilepicture_list", nil);
        }
    }
    return nil;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        [Colors updateTableViewCellBackground:cell];
        
        // handle custom table cells
        [Colors setTextColor:[Colors fontNormal] inView:cell.contentView];
        
        if (indexPath.row == _indexId) {
            ((UILabel*)[cell viewWithTag:100]).textColor = [Colors fontLight];
        } else if (indexPath.row == _indexFingerprint) {
            KeyFingerprintCell *kfc = (KeyFingerprintCell *)cell;
            kfc.fingerprintLabel.textColor = [Colors fontLight];
        } else if (indexPath.row == _indexNickname) {
            ((UILabel*)[cell viewWithTag:101]).textColor = [Colors fontLight];
        } else if (indexPath.row == _indexGroupMembership) {
            ((UILabel*)[cell viewWithTag:102]).textColor = [Colors fontLight];
        } else if (indexPath.row == _indexLinkedContact) {
            LinkedContactCell *lcc = (LinkedContactCell *)cell;
            lcc.displayNameLabel.textColor = [Colors fontLight];
        }
    } else {
        [Colors updateTableViewCell:cell];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    switch (indexPath.section) {
        case 0:
            if (indexPath.row == _indexLinkedContact) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                [self linkNewContact: cell];
            } else if (indexPath.row == _indexGroupMembership) {
                ContactGroupMembershipViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"contactGroupMembershipViewController"];
                vc.groupContact = self.contact;
                [self.navigationController pushViewController:vc animated:YES];
            }
            
            break;
        case 1:
            switch (indexPath.row) {
                case 0:
                    [self sendMessageAction:self];
                    break;
                case 1:
                    if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                        [self startThreemaCallAction];
                    } else {
                        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                            [self startPhoneCallAction];
                        }
                        else if (canExportConversation) {
                            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                            [self conversationAction:cell];
                            [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
                        }
                        else if ([ScanIdentityController canScan]) {
                            [self scanIdentityAction:nil];
                        }
                        else {
                            [self startPofilePictureAction];
                        }
                    }
                    break;
                case 2:
                    if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                            [self startPhoneCallAction];
                        }
                        else if (canExportConversation) {
                            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                            [self conversationAction:cell];
                            [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
                        }
                        else if ([ScanIdentityController canScan]) {
                            [self scanIdentityAction:nil];
                        }
                        else {
                            [self startPofilePictureAction];
                        }
                    } else {
                        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                            if (canExportConversation) {
                                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                                [self conversationAction:cell];
                                [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
                            }
                            else if (canExportConversation && [ScanIdentityController canScan]) {
                                [self scanIdentityAction:nil];
                            }
                            else {
                                [self startPofilePictureAction];
                            }
                        }
                        else {
                            if (canExportConversation && [ScanIdentityController canScan]) {
                                [self scanIdentityAction:nil];
                            }
                            else {
                                [self startPofilePictureAction];
                            }
                        }
                    }
                    break;
                case 3: {
                    if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                            if (canExportConversation) {
                                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                                [self conversationAction:cell];
                                [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
                            }
                            else if ([ScanIdentityController canScan]) {
                                [self scanIdentityAction:nil];
                            }
                            else {
                                [self startPofilePictureAction];
                            }
                        } else {
                            if (canExportConversation && [ScanIdentityController canScan]) {
                                [self scanIdentityAction:nil];
                            }
                            else {
                                [self startPofilePictureAction];
                            }
                        }
                    } else {
                        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                            if (canExportConversation && [ScanIdentityController canScan]) {
                                [self scanIdentityAction:nil];
                            }
                            else {
                                [self startPofilePictureAction];
                            }
                        } else {
                            [self startPofilePictureAction];
                        }
                    }
                    break;
                }
                case 4: {
                    if ([UserSettings sharedUserSettings].enableThreemaCall && is64Bit == 1) {
                        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                            if (canExportConversation && [ScanIdentityController canScan]) {
                                [self scanIdentityAction:nil];
                            } else {
                                [self startPofilePictureAction];
                            }
                        } else {
                            [self startPofilePictureAction];
                        }
                    } else {
                        if (SYSTEM_IS_IPAD == NO && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:+11111"]] && [self showPhoneCallButton]) {
                            [self startPofilePictureAction];
                        }
                    }
                    break;
                }
                case 5: {
                    [self startPofilePictureAction];
                    break;
                }
            }
            break;
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
            if (indexPath.row == _indexVerificationLevel) {
                [self performSegueWithIdentifier:@"VerificationSegue" sender:nil];
            }
            break;
        default:
            break;
    }
}

- (void)showEditContactVC {
    EditContactViewController *editVc = [self.storyboard instantiateViewControllerWithIdentifier:@"EditContactViewController"];
    editVc.contact = self.contact;
    [self.navigationController pushViewController:editVc animated:YES];
}

- (void)linkNewContact:(UIView *)view {
    
    /* Already linked? If so, give user a choice to unlink */
    if (cnContact != nil) {
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"unlink_contact", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            /* unlink contact */
            [[ContactStore sharedContactStore] unlinkContact:self.contact];
            [self updateView];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"choose_new_contact", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self linkNewContactCheckAuthorization];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
        }]];
        
        actionSheet.popoverPresentationController.sourceRect = view.frame;
        actionSheet.popoverPresentationController.sourceView = self.view;
        
        [self presentViewController:actionSheet animated:YES completion:nil];
    } else {
        [self linkNewContactCheckAuthorization];
    }
}

- (void)linkNewContactCheckAuthorization {
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized) {
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                DDLogInfo(@"Address book access has been granted");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self linkNewContactPick];
                });
            } else {
                DDLogInfo(@"Address book access has NOT been granted: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *accessAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"no_contacts_permission_title", nil) message:NSLocalizedString(@"no_contacts_permission_message", nil) preferredStyle:UIAlertControllerStyleAlert];
                    if (self.contact.cnContactId != nil) {
                        [accessAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"unlink_contact", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                            [[ContactStore sharedContactStore] unlinkContact:self.contact];
                            [self updateView];
                        }]];
                    }
                    [accessAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                    }]];
                    [self presentViewController:accessAlert animated:YES completion:nil];
                    
                    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
                });
            }
        }];
        return;
    } else {
        [self linkNewContactPick];
    }
}

- (void)linkNewContactPick {
    CNContactPickerViewController *picker = [[CNContactPickerViewController alloc] init];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - People picker delegate

-(void) contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact{
    [(StatusNavigationBar *)self.navigationController.navigationBar showOrHideStatusView];
    [[ContactStore sharedContactStore] linkContact:self.contact toCnContactId:contact.identifier];
    [self dismissViewControllerAnimated:YES completion:nil];
    [self updateView];
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty  {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    [(StatusNavigationBar *)self.navigationController.navigationBar showOrHideStatusView];
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - ProfilePictureRecipientCell delegate

- (void)valueChanged:(ProfilePictureRecipientCell *)cell {
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)];
    [self.tableView beginUpdates];
    [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

# pragma mark - preview actions

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems {
    NSString *sendMessageTitle = NSLocalizedString(@"send_message", nil);
    UIPreviewAction *sendMessageAction = [UIPreviewAction actionWithTitle:sendMessageTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        [self sendMessageAction:self];
    }];
    
    NSString *scanQrCodeTitle = NSLocalizedString(@"scan_qr", nil);
    UIPreviewAction *scanQrCodeAction = [UIPreviewAction actionWithTitle:scanQrCodeTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        
        // we need to present contact details first and present qr scanner on top of that
        [_delegate presentContactDetails:self onCompletion:^(ContactDetailsViewController *contactsDetailsViewController) {
            [contactsDetailsViewController scanIdentityAction:nil];
        }];
    }];
    
    
    return @[sendMessageAction, scanQrCodeAction];
}


#pragma mark - Notifications

- (void)colorThemeChanged:(NSNotification*)notification {
    [self setupColors];
}

- (void)showProfilePictureChanged:(NSNotification*)notification {
    [self updateView];
}

@end
