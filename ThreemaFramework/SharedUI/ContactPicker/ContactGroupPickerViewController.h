//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import <UIKit/UIKit.h>
#import "ModalNavigationController.h"
#import "Old_ThemedViewController.h"

@class ContactGroupPickerViewController;

@protocol ContactGroupPickerDelegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile;

- (void)contactPickerDidCancel:(ContactGroupPickerViewController*)contactPicker;

@end

@interface ContactGroupPickerViewController : Old_ThemedViewController

@property BOOL submitOnSelect;

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
//@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@property (weak, nonatomic) IBOutlet UIView *controlView;
@property (weak, nonatomic) IBOutlet UIView *buttonView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendButton;
@property (weak, nonatomic) IBOutlet UIButton *addTextButton;
@property (weak, nonatomic) IBOutlet UIButton *hideTextButton;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewBottomConstraint;
@property (weak, nonatomic) IBOutlet UIView *hairLineView;
@property (weak, nonatomic) IBOutlet UILabel *sendAsFileLabel;
@property (weak, nonatomic) IBOutlet UISwitch *sendAsFileSwitch;

// This is required to be strong when called from the ShareController class
@property (strong, nonatomic) id<ContactGroupPickerDelegate> delegate;

@property (nonatomic) BOOL enableMultiSelection;
@property (nonatomic) BOOL enableTextInput;
@property (nonatomic) BOOL enableControlView;

@property (nonatomic, strong) NSString *pickerTitle;
@property (nonatomic, strong) NSNumber *renderType;

@property (readonly) NSString *additionalTextToSend;

@property (strong, nonatomic) UISearchController *searchController;

+ (ModalNavigationController *)pickerFromStoryboardWithDelegate:(id<ModalNavigationControllerDelegate, ContactGroupPickerDelegate>)delegate;

- (IBAction)addTextAction:(id)sender;
- (IBAction)hideTextAction:(id)sender;
- (IBAction)cancelAction:(id)sender;
- (IBAction)doneAction:(id)sender;
- (IBAction)segmentedControlChanged:(id)sender;

@end
