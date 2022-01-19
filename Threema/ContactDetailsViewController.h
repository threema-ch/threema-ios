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

////  ContactDetailsViewController.h
////  Threema
////
////  Copyright (c) 2012 Threema GmbH. All rights reserved.
////
//
//#import <ContactsUI/ContactsUI.h>
//#import <UIKit/UIKit.h>
//#import "ThemedTableViewController.h"
//#import "ProfilePictureRecipientCell.h"
//
//@class Contact;
//@class ContactDetailsViewController;
//
//typedef void (^ContactDetailsCompletionBlock)(ContactDetailsViewController *contactsDetailsViewController);
//
//@protocol ContactDetailsViewControllerDelegate <NSObject>
//
//- (void)presentContactDetails:(ContactDetailsViewController *)contactsDetailsViewController onCompletion:(ContactDetailsCompletionBlock)onCompletion;
//
//@end
//
//
//@interface ContactDetailsViewController : ThemedTableViewController <CNContactPickerDelegate, ProfilePictureRecipientCellDelegate>
//
//@property (weak, nonatomic) IBOutlet UIView *headerView;
//@property (weak, nonatomic) IBOutlet UIButton *disclosureButton;
//@property (weak, nonatomic) IBOutlet UIImageView *imageView;
//@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
//@property (weak, nonatomic) IBOutlet UILabel *companyNameLabel;
//@property (weak, nonatomic) IBOutlet UIImageView *threemaTypeIcon;
//@property (weak, nonatomic) IBOutlet UIBarButtonItem *scanQrCodeBarButtonItem;
//
//@property (strong, nonatomic) Contact* contact;
//
//@property id<ContactDetailsViewControllerDelegate> delegate;
//
//@property BOOL hideActionButtons;
//
////- (IBAction)sendMessageAction:(id)sender;
//- (IBAction)scanIdentityAction:(id)sender;
////- (IBAction)emailConversationAction:(id)sender;
//
//@end
