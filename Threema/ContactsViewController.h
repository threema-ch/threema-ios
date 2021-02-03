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

#import <UIKit/UIKit.h>
#import "ThemedTableViewController.h"
#import <CoreData/CoreData.h>
#import "Threema-Swift.h"

@class Contact;
@class GroupProxy;

@interface ContactsViewController : ThemedTableViewController <NSFetchedResultsControllerDelegate, UISearchControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating>

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;

@property (weak, nonatomic) IBOutlet UIView *noContactsView;
@property (weak, nonatomic) IBOutlet UILabel *noContactsTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *noContactsMessageLabel;
@property (weak, nonatomic) IBOutlet UIView *countContactsFooterView;
@property (weak, nonatomic) IBOutlet UILabel *countContactsFooterLabel;
@property (weak, nonatomic) IBOutlet CompanyDirectoryCell *companyDirectoryCell;

@property (strong, nonatomic) UISearchController *searchController;

- (void)refresh;

- (BOOL)isWorkActive;

- (void)showDetailsForContact:(Contact*)contact;
- (void)showDetailsForGroup:(GroupProxy*)group;

- (void)setSelectionForContact:(Contact *)contact;
- (void)setSelectionForGroup:(GroupProxy *)group;
- (void)setSelectionForWorkContact:(Contact *)contact;

- (BOOL)showFirstEntryForCurrentMode;

- (IBAction)segmentedControlChanged:(id)sender;

- (IBAction)addAction:(id)sender;

@end
