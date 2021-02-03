//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2021 Threema GmbH
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

#import "GroupDetailsViewController.h"
#import "Conversation.h"
#import "Contact.h"
#import "GroupMemberCell.h"
#import "ContactPickerViewController.h"
#import "ContactDetailsViewController.h"
#import "ImageData.h"
#import "UIDefines.h"
#import "AvatarMaker.h"
#import "AppDelegate.h"
#import "AddMemberCell.h"
#import "BundleUtil.h"
#import "DeleteConversationAction.h"
#import "FullscreenImageViewController.h"
#import "EditGroupViewController.h"
#import "PickGroupMembersViewController.h"
#import "ModalNavigationController.h"
#import "ModalPresenter.h"
#import "UIImage+ColoredImage.h"
#import "CreateGroupNavigationController.h"
#import "UserSettings.h"
#import "Threema-Swift.h"
#import "MDMSetup.h"
#import "BundleUtil.h"

@interface GroupDetailsViewController () <MFMailComposeViewControllerDelegate>

@property BOOL canExportChat;

@end

@implementation GroupDetailsViewController {
    NSArray *members;
    Contact *selectedContact;
    
    NSInteger includeMediaIndex;
    NSInteger withoutMediaIndex;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedGroup:) name:kNotificationUpdatedGroup object:nil];
    
    self.navigationController.interactivePopGestureRecognizer.enabled  = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;

    _nameLabel.font = [UIFont boldSystemFontOfSize: _nameLabel.font.pointSize];
        
    UITapGestureRecognizer *disclosureTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedHeaderView)];
    [_disclosureButton addGestureRecognizer:disclosureTapRecognizer];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedImage)];
    [_imageView addGestureRecognizer:tapRecognizer];
    
    [self setupColors];
}

- (void)setupColors {
    [_nameLabel setTextColor:[Colors fontNormal]];
    _nameLabel.shadowColor = nil;
    
    [_creatorLabel setTextColor:[Colors fontLight]];
    _creatorLabel.shadowColor = nil;
    
    UIImage *disclosureImage = [self.disclosureButton.imageView.image imageWithTint:[Colors main]];
    [self.disclosureButton setImage:disclosureImage forState:UIControlStateNormal];

    
    if (@available(iOS 11.0, *)) {
        _imageView.accessibilityIgnoresInvertColors = true;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.view.alpha = 1.0;
    
    _canExportChat = [self canExportConversation];
    
    [self reloadMembers];
    [self.tableView reloadData];
    
    [self updateHeaderView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleTitle3];
    CGFloat size = fontDescriptor.pointSize;
    _nameLabel.font = [UIFont boldSystemFontOfSize:size];
}

- (void)setGroup:(GroupProxy *)newGroup {
    [_group.conversation removeObserver:self forKeyPath:@"members"];
    [_group.conversation removeObserver:self forKeyPath:@"groupName"];
    [_group.conversation removeObserver:self forKeyPath:@"groupImage"];
    
    _group = newGroup;
    
    [_group.conversation addObserver:self forKeyPath:@"members" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    [_group.conversation addObserver:self forKeyPath:@"groupName" options:0 context:nil];
    [_group.conversation addObserver:self forKeyPath:@"groupImage" options:0 context:nil];
}

- (void)dealloc {
    [_group.conversation removeObserver:self forKeyPath:@"members"];
    [_group.conversation removeObserver:self forKeyPath:@"groupName"];
    [_group.conversation removeObserver:self forKeyPath:@"groupImage"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateHeaderView {
    UIImage *avatarImage = [[AvatarMaker sharedAvatarMaker] avatarForConversation:_group.conversation size:_imageView.frame.size.width masked:NO];
    _imageView.image = avatarImage;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.layer.masksToBounds = YES;
    _imageView.layer.cornerRadius = _imageView.bounds.size.width / 2;
    
    _nameLabel.text = _group.name;
    
    if ([_group isOwnGroup]) {
        _disclosureButton.hidden = NO;
    } else {
        _disclosureButton.hidden = YES;
    }
    
    _creatorLabel.text = [_group creatorString];
    
    _headerView.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", _nameLabel.text, _creatorLabel.text];
}

- (void)reloadMembers {
    members = _group.sortedActiveMembers;
}

- (void)tappedHeaderView {
    [self showEditGroupVC];
}

- (void)tappedImage {
    if (_group.conversation.groupImage) {
        UIImage *image = [UIImage imageWithData:_group.conversation.groupImage.data];
        if (image != nil) {
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
            [self showEditGroupVC];
        }
    } else {
        [self showEditGroupVC];
    }
}

- (void)showEditGroupVC {
    if ([_group isOwnGroup] == NO) {
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateGroup" bundle:nil];
    EditGroupViewController *editVC = [storyboard instantiateViewControllerWithIdentifier:@"EditGroupViewController"];
    editVC.group = _group;
    
    UINavigationController *navigationVC = [[UINavigationController alloc] initWithRootViewController:editVC];
    
    [ModalPresenter present:navigationVC on:self fromRect:_headerView.frame inView:self.view];
}

- (void)showEditGroupMembersVCFrom:(NSIndexPath *)indexPath {
    if ([_group isOwnGroup] == NO || [self canAddMember] == NO) {
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateGroup" bundle:nil];
    PickGroupMembersViewController *pickMembersVC = [storyboard instantiateViewControllerWithIdentifier:@"PickGroupMembersViewController"];
    pickMembersVC.group = _group;
    
    UINavigationController *navigationVC = [[UINavigationController alloc] initWithRootViewController:pickMembersVC];
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    [ModalPresenter present:navigationVC on:self fromRect:cell.frame inView:self.view];
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ShowContact"]) {
        ContactDetailsViewController *detailsVc = (ContactDetailsViewController*)segue.destinationViewController;
        detailsVc.contact = selectedContact;
    }
    else if ([segue.identifier isEqualToString:@"ShowPushSetting"]) {
        NotificationSettingViewController *notificationSettingViewController = (NotificationSettingViewController *)segue.destinationViewController;
        notificationSettingViewController.identity = [NSString stringWithHexData:self.group.groupId];
        notificationSettingViewController.isGroup = YES;
        notificationSettingViewController.conversation = _group.conversation;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"members"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadMembers];
            [self updateHeaderView];
            [self.tableView reloadData];
        });
    } else if ([keyPath isEqualToString:@"groupName"] || [keyPath isEqualToString:@"groupImage"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateHeaderView];
        });
    }
}

- (void)syncMembers {
    [_group syncGroupInfoToAll];
    
    [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"group_sync_title", nil) message:NSLocalizedString(@"group_sync_message", nil) actionOk:nil];
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (void)exportChatWithMedia:(bool)withMedia {
    EntityManager *em = [[EntityManager alloc] init];
    ConversationExporter *exporter = [[ConversationExporter alloc] initWithViewController:self conversation: self.group.conversation
                                                                            entityManager:em withMedia:withMedia];
    [exporter exportGroupConversation];
}

- (void)conversationActionFromRect:(CGRect)rect {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedString(@"include_media_title", nil), kExportConversationMediaSizeLimit] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"include_media", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self exportChatWithMedia:true];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"without_media", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self exportChatWithMedia:false];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1] animated:YES];
    }]];
    
    actionSheet.popoverPresentationController.sourceRect = rect;
    actionSheet.popoverPresentationController.sourceView = self.view;
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)sendMessageAction {
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          _group.conversation, kKeyConversation,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
}

- (BOOL)canExportConversation {
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    if (_group.conversation == nil || [mdmSetup disableExport]) {
        return NO;
    }
    return _group.conversation.messages.count > 0;    
}

- (void)leaveGroup {
    
    NSString *title = [self alertMessage];
    
    [UIAlertTemplate showAlertWithOwner:self title:title message:nil titleOk:[BundleUtil localizedStringForKey:@"leave"] actionOk:^(UIAlertAction * _Nonnull action) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:3] animated:YES];
        [self processLeaveGroup];
    } titleCancel:[BundleUtil localizedStringForKey:@"cancel"] actionCancel:^(UIAlertAction * _Nonnull action) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:3] animated:YES];
    }];
}

- (NSString *)alertMessage {
    NSString *message;
    if (_group.conversation.isGroup && _group.conversation.contact == nil) {
        message = NSLocalizedString(@"group_admin_delete_confirm", nil);
    } else {
        message = NSLocalizedString(@"group_delete_confirm", nil);
    }
    
    return message;
}

- (void)processLeaveGroup {
     [_group leaveGroup];
    [self reloadMembers];
    [self.tableView reloadData];
    [UIAlertTemplate showAlertWithOwner:self title:@"" message:NSLocalizedString(@"group_member_self_left", nil) actionOk:nil];
}

- (BOOL)canAddMember {
    return (_group.conversation.members.count < [[BundleUtil objectForInfoDictionaryKey:@"ThreemaMaxGroupMembers"] intValue]);
}

- (void)cloneGroup {
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    if ([mdmSetup disableCreateGroup]) {
        [UIAlertTemplate showAlertWithOwner:self title:@"" message:NSLocalizedString(@"disabled_by_device_policy", nil) actionOk:nil];
        return;
    }
    NSString *title = NSLocalizedString(@"group_clone_title", nil);
    NSString *message = NSLocalizedString(@"group_clone_message", nil);
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"no", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"yes", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateGroup" bundle:nil];
        CreateGroupNavigationController *navVC = (CreateGroupNavigationController *)[storyboard instantiateInitialViewController];
        navVC.cloneGroupId = _group.groupId;
        [self presentViewController:navVC animated:YES completion:nil];
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0 && (indexPath.row-1) == members.count) {
        [Colors updateTableViewCellBackground:cell];
        [Colors setTextColor:[Colors main] inView:cell.contentView];
    } else if (indexPath.section == 3   ) {
        // handle custom table cells
        [Colors updateTableViewCellBackground:cell];        
        [Colors setTextColor:[Colors red] inView:cell.contentView];
    } else {
        [Colors updateTableViewCell:cell];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        NSInteger n = members.count + 2;
        if ([_group isOwnGroup]) {
            n += 2;    /* me = creator */
        }
        
        return n;
    } else if (section == 1) {
        if (_hideActionButtons) {
            return 0;
        }
        
        if (_canExportChat) {
            return 2;
        }
        
        return 1;
    } else if (section == 2) {
        if (_hideActionButtons || [_group isSelfMember] == false) {
            return 0;
        }
        
        return 1;
    } else if (section == 3) {
        if (_hideActionButtons || [_group isSelfMember] == false) {
            return 0;
        }
        
        return 1;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            /* first = me */
            GroupMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GroupMemberCell"];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            cell.isSelfMember = YES;
            cell.contact = nil;
            
            if (![_group isSelfMember]) {
                cell.nameLabel.text = [BundleUtil localizedStringForKey:@"you are not a member"];
            }
            return cell;
        } else if ((indexPath.row-1) < members.count) {
            GroupMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GroupMemberCell"];
            cell.isSelfMember = NO;
            cell.contact = [members objectAtIndex:indexPath.row-1];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            return cell;
        }
        else if ((indexPath.row-1) == members.count && [_group isOwnGroup]) {
            BOOL canAddMember = [self canAddMember];
            AddMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AddMemberCell"];
            cell.userInteractionEnabled = canAddMember;
            cell.plusImage.alpha = canAddMember ? 1.0 : 0.4;
            cell.addLabel.enabled = canAddMember;
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            return cell;
        }
        else if ((indexPath.row-1) == members.count && ![_group isOwnGroup]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CloneCell"];
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            return cell;
        }
        else if ((indexPath.row-1) == (members.count+1)) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SyncCell"];
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            return cell;
        }
        else if ((indexPath.row-1) == (members.count+2)) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CloneCell"];
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            return cell;
        }
    } else if (indexPath.section == 1) {
        NSString *cellIdentifier;
        if (indexPath.row == 0) {
            cellIdentifier = @"SendMessageCell";
        } else {
            cellIdentifier = @"ExportConversationCell";
        }
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        return cell;
    } else if (indexPath.section == 2) {
        UITableViewCell *pushSettingCell = [tableView dequeueReusableCellWithIdentifier:@"PushSettingCell"];
        pushSettingCell.textLabel.text = NSLocalizedString(@"pushSetting_title", @"");
        return pushSettingCell;
    } else if (indexPath.section == 3) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LeaveGroupCell"];
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        return cell;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 40.0;
    }
    return UITableViewAutomaticDimension;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"members", nil);
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row != 0 && (indexPath.row-1) < members.count) {
            selectedContact = [members objectAtIndex:indexPath.row-1];
            [self performSegueWithIdentifier:@"ShowContact" sender:self];
        } else if ((indexPath.row-1) == members.count && [_group isOwnGroup]) {
            [self showEditGroupMembersVCFrom:indexPath];
        }
        else if ((indexPath.row-1) == members.count && ![_group isOwnGroup]) {
            [self cloneGroup];
        }
        else if ((indexPath.row-1) == (members.count+1)) {
            [self syncMembers];
        }
        else if ((indexPath.row-1) == (members.count+2)) {
            [self cloneGroup];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self sendMessageAction];
        } else {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            [self conversationActionFromRect:cell.frame];
        }
    } else if (indexPath.section == 2) {
        
    } else if (indexPath.section == 3) {
        [self leaveGroup];
    }
}

#pragma mark - Table view delegae

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && _group.isOwnGroup) {
        if (indexPath.row == 0) {
            /* first = me */
            return NO;
        } else if ((indexPath.row-1) < members.count) {
            return YES;
        }
    }
    
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Contact *contact = [members objectAtIndex:indexPath.row-1];
        
        [_group adminRemoveMember:contact];
        
        [self reloadMembers];
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}


#pragma mark - Mail composer delegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

# pragma mark - preview actions

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems {
    NSMutableArray *actions = [NSMutableArray array];
    
    NSString *sendMessageTitle = NSLocalizedString(@"send_message", nil);
    UIPreviewAction *sendMessageAction = [UIPreviewAction actionWithTitle:sendMessageTitle style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        
        [self sendMessageAction];
    }];
    [actions addObject:sendMessageAction];
    
    if (_delegate) {
        NSString *leaveGroupTitle = NSLocalizedString(@"leave_group", nil);
        UIPreviewAction *leaveGroupAction = [UIPreviewAction actionWithTitle:leaveGroupTitle style:UIPreviewActionStyleDestructive handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            
            [_delegate presentGroupDetails:self onCompletion:^(GroupDetailsViewController *groupDetailsViewController) {
                [groupDetailsViewController leaveGroup];
            }];
        }];
        [actions addObject:leaveGroupAction];
    }
    
    return actions;
}


#pragma mark - Notifications

- (void)updatedGroup:(NSNotification*)notification {
    NSString *creatorString = notification.userInfo[@"creatorString"];
    NSData *groupId = notification.userInfo[@"groupId"];
    if ([_group.creatorString isEqualToString:creatorString] && _group.groupId == groupId) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadMembers];
            [self updateHeaderView];
            [self.tableView reloadData];
        });
    }
}

@end
