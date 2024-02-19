//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

#import "ContactGroupPickerViewController.h"
#import "ContactTableDataSource.h"
#import "GroupTableDataSource.h"
#import "RecentTableDataSource.h"
#import "WorkContactTableDataSource.h"
#import "BundleUtil.h"
#import "RectUtil.h"
#import "AppGroup.h"
#import "LicenseStore.h"
#import "Old_PickerContactCell.h"
#import "Conversation.h"

#define LAST_SELECTED_MODE @"ContactGroupPickerLastSelectedMode"

typedef enum : NSUInteger {
    ModeContact,
    ModeGroup,
    ModeRecent,
    ModeWorkContact
} SelectionMode;


@interface ContactGroupPickerViewController () <UITableViewDelegate, UISearchBarDelegate, UISearchResultsUpdating>

@property SelectionMode mode;

@property id<ContactGroupDataSource> currentDataSource;

@property CGFloat searchBarHeight;
@property BOOL isSearchBarHidden;
@property BOOL isTextInputHidden;

@end

@implementation ContactGroupPickerViewController

+ (UIStoryboard *)contactPickerStoryboard {
    NSBundle *frameworkBundle = [BundleUtil frameworkBundle];
    return [UIStoryboard storyboardWithName:@"ContactPicker" bundle:frameworkBundle];
}

+ (ModalNavigationController *)pickerFromStoryboardWithDelegate:(id<ModalNavigationControllerDelegate, ContactGroupPickerDelegate>)delegate {
    UIStoryboard *storyboard = [ContactGroupPickerViewController contactPickerStoryboard];
    ModalNavigationController *navigationController = [storyboard instantiateInitialViewController];
    navigationController.dismissOnTapOutside = YES;
    navigationController.modalDelegate = delegate;
    
    ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)[navigationController topViewController];
    picker.delegate = delegate;
    picker.enableMultiSelection = YES; //defaults to YES
    picker.enableTextInput = YES; //defaults to YES
    picker.enableControlView = YES;
    
    return navigationController;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([_rightBarButtonTitle length] == 0) {
        _rightBarButtonTitle = [BundleUtil localizedStringForKey:@"send"];
    }
    
    self.overrideUserInterfaceStyle = [UserSettings sharedUserSettings].darkTheme ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    
    WorkContactTableDataSource *workDataSource = [WorkContactTableDataSource workContactTableDataSource];
    if ([LicenseStore requiresLicenseKey] && workDataSource.countOfWorkContacts > 0) {
        [self.segmentedControl insertSegmentWithTitle:[BundleUtil localizedStringForKey:@"work"] atIndex:ModeWorkContact animated:NO];
    }
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSNumber *type = [defaults objectForKey:LAST_SELECTED_MODE];
    if (type) {
        _mode = type.integerValue;
        
    } else {
        _mode = ModeContact;
    }
    
    _sendAsFileSwitch.on = false;
    
    self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
    self.searchController.searchBar.showsScopeBar = NO;
    self.searchController.searchBar.scopeButtonTitles = nil;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeNone;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.searchController.searchBar sizeToFit];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.definesPresentationContext = NO;
    self.searchController.hidesNavigationBarDuringPresentation = false;
    
    [Colors updateWithSearchBar:_searchController.searchBar];
    
    self.navigationItem.searchController = _searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    _searchBarHeight = self.searchController.searchBar.frame.size.height;
    
    [self updateUIStrings];
    
    if (_submitOnSelect || !_enableControlView) {
        _controlView.hidden = YES;
        [_controlView removeFromSuperview];
        _tableViewBottomConstraint.constant = 0.0;
    }
    
    _isTextInputHidden = YES;
    
    _tableView.dataSource = _currentDataSource;
    _tableView.delegate = self;
    _tableView.allowsMultipleSelection = _enableMultiSelection;
    
    [self registerForKeyboardNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    
    [self updateColors];
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    CGRect frame = CGRectZero;
    frame.size.height = CGFLOAT_MIN;
    [self.tableView setTableHeaderView:[[UIView alloc] initWithFrame:frame]];

    [self.tableView registerClass:GroupCell.class forCellReuseIdentifier:@"GroupCell"];
}

- (void)updateColors {
    self.view.backgroundColor = Colors.backgroundViewController;
    self.tableView.backgroundColor = Colors.backgroundNavigationController;
    self.navigationController.navigationBar.backgroundColor = Colors.backgroundNavigationController;
    
    _segmentedControl.backgroundColor = Colors.backgroundNavigationController;
    _segmentedControl.selectedSegmentTintColor = Colors.backgroundSegmentedControl;
    
    _controlView.backgroundColor = Colors.backgroundView;
    _buttonView.backgroundColor = Colors.backgroundView;
    [_sendButton setTintColor:Colors.textLink];
    [_addTextButton setTintColor:Colors.textLink];
    [_hideTextButton setTintColor:Colors.textLink];
    
    _textView.backgroundColor = Colors.backgroundView;
    
    [Colors updateWithTableView:self.tableView];
    [Colors updateWithSearchBar:_searchController.searchBar];
    [Colors updateKeyboardAppearanceFor:self.textView];
    
    [_hairLineView setBackgroundColor:Colors.hairLine];
    
    _sendAsFileLabel.textColor = Colors.textLink;
    
    [self.navigationItem.leftBarButtonItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                   UIColor.primary, NSForegroundColorAttributeName,
                                        nil] forState:UIControlStateNormal];
    [self.navigationItem.leftBarButtonItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                   UIColor.primary, NSForegroundColorAttributeName,
                                                                   nil] forState:UIControlStateHighlighted];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.titleView = _segmentedControl;
    
    self.segmentedControl.selectedSegmentIndex = _mode;
    [self segmentedControlChanged:nil];
    
    if (self.preselectedConversations != nil) {
        _mode = ModeRecent;
        [self updateDataSourceMode];
        for (Conversation *conv in self.preselectedConversations) {
            if ([_currentDataSource isKindOfClass:RecentTableDataSource.class]) {
                [(RecentTableDataSource *) _currentDataSource insertSelectedConversation:conv];
            }
        }
        [self.tableView reloadData];
    }
    
    if (_renderType == nil) {
            _renderType = @0;
        }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (_enableTextInput == NO) {
        _addTextButton.hidden = YES;
    }
    [self updateButtons];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    [defaults setValue:[NSNumber numberWithInteger:_mode] forKey:LAST_SELECTED_MODE];
}

- (void)setEnableMultiSelection:(BOOL)allowMulitSelection {
    _enableMultiSelection = allowMulitSelection;
    _tableView.allowsMultipleSelection = _enableMultiSelection;
}

- (void)updateUIStrings {    
    // iOS 10 and 12 have different subviews sorting, so we have to check it with name and replace it at the end with the image
    
    [self.segmentedControl setTitle:@"contacts" forSegmentAtIndex:ModeContact];
    [self.segmentedControl setTitle:@"groups" forSegmentAtIndex:ModeGroup];
    [self.segmentedControl setTitle:@"recent" forSegmentAtIndex:ModeRecent];
    if ([LicenseStore requiresLicenseKey] && self.segmentedControl.numberOfSegments == 4) {
        [self.segmentedControl setTitle:@"work" forSegmentAtIndex:ModeWorkContact];
    }
    
    for (int i = 0; i < self.segmentedControl.numberOfSegments; i++) {
        UIView *segment = self.segmentedControl.subviews[i];
        for (id subview in segment.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if ([label.text isEqualToString:@"contacts"]) {
                    segment.accessibilityLabel = [BundleUtil localizedStringForKey:@"contacts"];
                }
                else if ([label.text isEqualToString:@"groups"]) {
                    segment.accessibilityLabel = [BundleUtil localizedStringForKey:@"groups"];
                }
                else if ([label.text isEqualToString:@"recent"]) {
                    segment.accessibilityLabel = [BundleUtil localizedStringForKey:@"recent"];
                }
                else if ([label.text isEqualToString:@"work"]) {
                    segment.accessibilityLabel = [BundleUtil localizedStringForKey:@"work"];
                }
            }
        }
    }
    [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeContact];
    [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeGroup];
    [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeRecent];
    [self.segmentedControl setImage:[[BundleUtil imageNamed:@"Contact"] imageWithTintColor:Colors.text renderingMode:UIImageRenderingModeAlwaysOriginal] forSegmentAtIndex:ModeContact];
    [self.segmentedControl setImage:[[BundleUtil imageNamed:@"Group"] imageWithTintColor:Colors.text renderingMode:UIImageRenderingModeAlwaysOriginal] forSegmentAtIndex:ModeGroup];
    [self.segmentedControl setImage:[[BundleUtil imageNamed:@"Recent"] imageWithTintColor:Colors.text renderingMode:UIImageRenderingModeAlwaysOriginal] forSegmentAtIndex:ModeRecent];
    
    if ([LicenseStore requiresLicenseKey] && self.segmentedControl.numberOfSegments == 4) {
        [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeWorkContact];
        [self.segmentedControl setImage:[[BundleUtil imageNamed:@"Case"] imageWithTintColor:Colors.text renderingMode:UIImageRenderingModeAlwaysOriginal] forSegmentAtIndex:ModeWorkContact];
    }
    
    [_addTextButton setTitle:[BundleUtil localizedStringForKey:@"addText"] forState:UIControlStateNormal];
    [_hideTextButton setTitle:[BundleUtil localizedStringForKey:@"hide"] forState:UIControlStateNormal];
    [_sendButton setTitle:[BundleUtil localizedStringForKey:@"send"]];
    [_sendAsFileLabel setText:[BundleUtil localizedStringForKey:@"send_as_file"]];
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

- (void)refresh {
    [self updateColors];
    
    [_tableView reloadData];
}

# pragma mark - Keyboard Notifications

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self processKeyboardNotification:notification willHide:NO];
    
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self processKeyboardNotification:notification willHide:YES];
}

- (void)processKeyboardNotification:(NSNotification*)notification willHide:(BOOL)willHide {
    NSDictionary* info = [notification userInfo];
    
    NSNumber *durationValue = info[UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration = durationValue.doubleValue;
    
    NSNumber *curveValue = info[UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve animationCurve = curveValue.intValue;
    
    CGRect keyboardRect = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = willHide ? 0.0f : keyboardRect.size.height;

    [UIView animateWithDuration:animationDuration delay:0 options:(animationCurve << 16 | UIViewAnimationOptionBeginFromCurrentState) animations:^{
        CGFloat controlViewOffset = 0.0;
        if (_isTextInputHidden == true) {
            controlViewOffset = _buttonView.frame.size.height;
        } else {
            controlViewOffset = _controlView.frame.size.height;
        }
        
        CGFloat offset = willHide == true ? self.view.safeAreaInsets.bottom : keyboardHeight + controlViewOffset;
        
        float difference = self.view.safeAreaLayoutGuide.layoutFrame.size.height - self.view.frame.size.height;
        if (willHide == false) {
            offset += difference;
        }
        
        _tableViewBottomConstraint.constant =  offset;
    } completion:^(BOOL finished) {
    }];
}


#pragma mark - UIApplication Notifications

- (void)willResignActive:(NSNotification *)notification {
    [self hideTextAction:nil];
}


#pragma mark - table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[UITableViewCell class]]) {
        if (![cell isKindOfClass:[GroupCell class]]) {
            [Colors updateWithCell:cell setBackgroundColor:true];
        }
    }
    
    if ([cell isKindOfClass:[Old_PickerContactCell class]]) {
        Old_PickerContactCell *pickerContactCell = (Old_PickerContactCell *)cell;
        [pickerContactCell updateColors];
        BOOL found = false;
        for (Conversation *conversation in [_currentDataSource selectedConversations]) {
            if (conversation.contact != nil && conversation.contact == pickerContactCell.contact && !conversation.isGroup) {
                found = true;
            }
        }
        if (found == true) {
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
    
    if ([cell isKindOfClass:[GroupCell class]]) {
        GroupCell *groupCell = (GroupCell *)cell;
        
        groupCell.backgroundColor = [UIColor clearColor];

        EntityManager *entityManager = [EntityManager new];
        MessagePermission *messagePermission = [[MessagePermission alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore] userSettings:[UserSettings sharedUserSettings] groupManager:[[GroupManager alloc] initWithEntityManager:entityManager] entityManager:entityManager];
        
        if ([messagePermission canSendWithGroupID:groupCell.group.groupID groupCreatorIdentity:groupCell.group.groupCreatorIdentity reason:nil]) {
            groupCell.contentView.alpha = 1.0;
            groupCell.userInteractionEnabled = YES;
        } else {
            groupCell.contentView.alpha = 0.5;
            groupCell.userInteractionEnabled = NO;
        }
        
        BOOL found = false;
        for (Conversation *conversation in [_currentDataSource selectedConversations]) {
            if (conversation.groupId != nil && [conversation.groupId isEqualToData:groupCell.group.groupID]) {
                found = true;
            }
        }
        if (found == true) {
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [_currentDataSource selectedCellAtIndexPath:indexPath selected:YES];
    
    if (_submitOnSelect) {
        [self.delegate contactPicker:self didPickConversations:_currentDataSource.selectedConversations renderType:_renderType sendAsFile:_sendAsFileSwitch.on];
    } else {
        [self updateButtons];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [_currentDataSource selectedCellAtIndexPath:indexPath selected:NO];
    [self updateButtons];
}

- (void)updateButtons {
    NSUInteger count = [_currentDataSource selectedConversations].count;
    BOOL hasSelection = count > 0;
    _sendButton.enabled = hasSelection;
    if (hasSelection) {
        [_sendButton setTitle:[NSString stringWithFormat:@"%@ (%lu)", _rightBarButtonTitle, (unsigned long)count]];
    } else {
        [_sendButton setTitle:_rightBarButtonTitle];
    }
}

- (void)hideSearchBar:(BOOL)hide {
    if (_isSearchBarHidden == hide) {
        return;
    }
    
    _isSearchBarHidden = hide;
    
    [UIView animateWithDuration:0.3 animations:^{
        [self.searchController.searchBar setHidden:hide];
    }];
}

- (void)hideTextInput:(BOOL)hide {
    if (_isTextInputHidden == hide) {
        return;
    }
    
    if (hide) {
        [self updateAddButtonTitle];
    }
    
    _isTextInputHidden = hide;
    
    [UIView animateWithDuration:0.3 animations:^{
        _hideTextButton.hidden = hide;
        _addTextButton.hidden = !hide;
        _textView.hidden = hide;
    }];
}

- (void)updateAddButtonTitle {
    NSString *addButtonTitle;
    if ([self hasAdditionalText]) {
        _addTextButton.frame = [RectUtil setWidthOf:_addTextButton.frame width:150.0];
        addButtonTitle = [self trimmedText];
    } else {
        addButtonTitle = [BundleUtil localizedStringForKey:@"addText"];
    }
    
    [_addTextButton setTitle:addButtonTitle forState:UIControlStateNormal];
}

- (NSString *)additionalTextToSend {
    if ([self hasAdditionalText]) {
        return [self trimmedText];
    } else {
        return nil;
    }
}

- (BOOL)hasAdditionalText {
    return [self trimmedText].length > 0;
}

- (NSString *)trimmedText {
    return [_textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [_textView resignFirstResponder];
    [_searchController.searchBar resignFirstResponder];
    [self hideTextInput:YES];
}

#pragma mark - Actions

- (IBAction)addTextAction:(id)sender {
    [self hideTextInput:NO];
    [_textView becomeFirstResponder];
    _controlView.backgroundColor = self.view.backgroundColor;
}

- (IBAction)hideTextAction:(id)sender {
    [self hideTextInput:YES];
    
    if (_mode != ModeRecent) {
        [self hideSearchBar:NO];
    }
    
    [_textView resignFirstResponder];
    _controlView.backgroundColor = _buttonView.backgroundColor;
    _textView.backgroundColor = _buttonView.backgroundColor;
}

- (IBAction)cancelAction:(id)sender {
    [self.delegate contactPickerDidCancel:self];
}

- (IBAction)doneAction:(id)sender {
    // If the delegate pushes a view controller while `searchController` is still setting itself to inactive
    // Nothing will happen and the following warning will be logged:
    // pushViewController:animated: called on while an existing transition or presentation is occurring;
    // the navigation stack will not be updated.
    //
    // Setting `searchController` to inactive doesn't matter as much when we're moving to another view anyways.
    if (!_delegateDisablesSearchController) {
        [self.searchController setActive:false];
    }
    
    [self.delegate contactPicker:self didPickConversations:_currentDataSource.selectedConversations renderType:_renderType sendAsFile:_sendAsFileSwitch.on];
}

- (IBAction)segmentedControlChanged:(id)sender {
    _mode = self.segmentedControl.selectedSegmentIndex;
    
    [self updateDataSourceMode];
}

- (void)updateDataSourceMode {
    [_textView resignFirstResponder];
    [self hideTextInput:YES];
    
    switch (_mode) {
        case ModeContact:
            [self hideSearchBar:NO];
            
            _currentDataSource = [ContactTableDataSource contactTableDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        case ModeGroup:
            [self hideSearchBar:NO];
            
            _currentDataSource = [GroupTableDataSource groupTableDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        case ModeRecent:
            [self hideSearchBar:YES];
            
            _currentDataSource = [RecentTableDataSource recentTableDataSource];
            break;
            
        case ModeWorkContact:
            [self hideSearchBar:NO];
            
            _currentDataSource = [WorkContactTableDataSource workContactTableDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
            
        default:
            break;
    }
    
    [self updateButtons];
    
    _tableView.dataSource = _currentDataSource;
    [self.tableView reloadData];
}


#pragma mark - Scroll view delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [_searchController.searchBar resignFirstResponder];
    [_textView resignFirstResponder];
    [self hideTextInput:YES];
    if (_mode != ModeRecent) {
        [self hideSearchBar:NO];
    }
}

#pragma mark - Search bar delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSArray *searchWords = [self searchWordsForText:searchText];    
    [_currentDataSource filterByWords: searchWords];
    
    [self.tableView reloadData];
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSArray *searchWords = [self searchWordsForText:_searchController.searchBar.text];
    [_currentDataSource filterByWords: searchWords];
    
    [self.tableView reloadData];
}

- (NSArray *)searchWordsForText:(NSString *)text {
    NSArray *searchWords = nil;
    if (text && [text length] > 0) {
        searchWords = [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    
    return searchWords;
}

@end
