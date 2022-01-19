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

#import "ContactGroupMembershipViewController.h"
#import "GroupProxy.h"
#import "ContactGroupCell.h"
#import "EntityManager.h"

@interface ContactGroupMembershipViewController ()

@property NSArray *groups;
@property Contact *contact;
@end

@implementation ContactGroupMembershipViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedString(@"groups", nil);
    
    [self updateGroups];
}

- (void)setGroupContact:(Contact *)contact {
    _contact = contact;
    [self updateGroups];
}

- (void)updateGroups {
    EntityManager *entityManager = [[EntityManager alloc] init];
    NSArray *groupConversations = [entityManager.entityFetcher groupConversationsForContact:_contact];
    
    NSMutableArray *newGroups = [NSMutableArray array];
    for (Conversation *conversation in groupConversations) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
        [newGroups addObject:group];
    }
    
    _groups = newGroups;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_groups count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactGroupCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactGroupCell"];
    if (cell == nil) {
        cell = [[ContactGroupCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ContactGroupCell"];
    }
    
    GroupProxy *group = [_groups objectAtIndex:indexPath.row];
    cell.group = group;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    GroupProxy *group = [_groups objectAtIndex:indexPath.row];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowGroup object:nil userInfo:[NSDictionary dictionaryWithObject:group forKey:kKeyGroup]];
}

@end
