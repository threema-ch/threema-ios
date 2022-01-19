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

#import <QuartzCore/QuartzCore.h>

#import "IdentityVerifiedViewController.h"
#import "Contact.h"
#import "AvatarMaker.h"
#import "BundleUtil.h"
#import "FeatureMask.h"
#import "ServerConnector.h"
#import "Threema-Swift.h"
#import "UIDefines.h"

@interface IdentityVerifiedViewController ()

@end

@implementation IdentityVerifiedViewController {
    PublicKeyView *publicKeyView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.contactImage.contentMode = UIViewContentModeScaleAspectFill;
    self.contactImage.layer.cornerRadius = self.contactImage.frame.size.width/2;
    self.contactImage.layer.masksToBounds = YES;
    _threemaTypeIcon.image = [Utils threemaTypeIcon];
    
    [self setupColors];
}

- (void)setupColors {
    [_nameLabel setTextColor:[Colors fontNormal]];
    _nameLabel.shadowColor = nil;
    
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

- (void)updateView {
    self.sendMessageLabel.text = [BundleUtil localizedStringForKey:@"send_message"];
    self.threemaCallLabel.text = [BundleUtil localizedStringForKey:@"call_voip_not_supported_title"];
    
    self.title = self.contact.displayName;
    self.nameLabel.text = self.contact.displayName;
    
    self.contactImage.image = [[AvatarMaker sharedAvatarMaker] avatarForContact:self.contact size:self.contactImage.frame.size.width masked:NO];
    _threemaTypeIcon.hidden = [Utils hideThreemaTypeIconForContact:self.contact];
    
    self.identityLabel.text = self.contact.identity;
    self.publicKeyCell.textLabel.text = [BundleUtil localizedStringForKey:@"public_key"];
    self.verificationLevelCell.contact = self.contact;
    
    if (self.contact.isWorkContact == true) {
        _verificationLevelImage.image = StyleKit.verificationBig4;
    } else {
        _verificationLevelImage.image = StyleKit.verificationBig2;
    }
    
    if (self.contact.isGatewayId || !is64Bit) {
        self.threemaCallCell.hidden = YES;
    }
    
    publicKeyView = [[PublicKeyView alloc] initFor:_contact];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        [Colors updateTableViewCellBackground:cell];
        [Colors setTextColor:[Colors main] inView:cell.contentView];
    } else {
        [Colors updateTableViewCell:cell];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (selectedCell == self.sendMessageCell) {
        [self dismissViewControllerAnimated:YES completion:^{
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys: self.contact, kKeyContact, [NSNumber numberWithBool:YES], kKeyForceCompose, nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
        }];
    }
    else if (selectedCell == self.threemaCallCell) {
        [self dismissViewControllerAnimated:YES completion:^{
            NSInteger state = [[VoIPCallStateManager shared] currentCallState];
            if (state == CallStateIdle) {
                [FeatureMask checkFeatureMask:FEATURE_MASK_VOIP forContacts:[NSSet setWithObjects:self.contact, nil] onCompletion:^(NSArray *unsupportedContacts) {
                    if (unsupportedContacts.count == 0) {
                        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                        if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
                            VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:ActionCall contact:self.contact callId:nil completion:nil];
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
    }
    else if (selectedCell == self.publicKeyCell) {
        [publicKeyView show];
        [tableView deselectRowAtIndexPath:indexPath animated:true];
    }
}

- (IBAction)done:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
