//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2022 Threema GmbH
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

#import "MessageDetailsViewController.h"
#import "BaseMessage.h"
#import "BrandingUtils.h"
#import "NSString+Hex.h"

@interface MessageDetailsViewController ()

@end

@implementation MessageDetailsViewController


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.messageIdLabel.text = [NSString stringWithHexData:self.message.id];
    
    if (!self.message.isOwn.boolValue) {
        self.sendDateLabel.text = [DateFormatter shortStyleDateTime:self.message.remoteSentDate];
        self.deliveredDateLabel.text = [DateFormatter shortStyleDateTime:self.message.deliveryDate];
        
        if (self.message.readDate != nil)
            self.readDateLabel.text = [DateFormatter shortStyleDateTime:self.message.readDate];
        else
            self.readDateLabel.text = @"";
        
        self.ackDateLabel.text = @"";
    } else {
        self.sendDateLabel.text = [DateFormatter shortStyleDateTime:self.message.date];
        
        if (self.message.deliveryDate != nil)
            self.deliveredDateLabel.text = [DateFormatter shortStyleDateTime:self.message.deliveryDate];
        else
            self.deliveredDateLabel.text = @"";
        
        if (self.message.readDate != nil)
            self.readDateLabel.text = [DateFormatter shortStyleDateTime:self.message.readDate];
        else
            self.readDateLabel.text = @"";
        
        if (self.message.userackDate != nil)
            self.ackDateLabel.text = [DateFormatter shortStyleDateTime:self.message.userackDate];
        else
            self.ackDateLabel.text = @"";
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(nonnull UITableViewCell *)cell forRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    
    if (!self.message.isOwn.boolValue) {
        if (self.message.remoteSentDate != nil && indexPath.row == 0)
            cell.hidden = NO;
        else if (self.message.deliveryDate != nil && indexPath.row == 1)
            cell.hidden = NO;
        else if (self.message.readDate != nil && indexPath.row == 2)
            cell.hidden = NO;
        else if (indexPath.row == 4)
            cell.hidden = NO;
        else
            cell.hidden = YES;
    } else {
        if (self.message.date == nil && indexPath.row == 0)
            cell.hidden = YES;
        else if (self.message.deliveryDate == nil && indexPath.row == 1)
            cell.hidden = YES;
        else if (self.message.readDate == nil && indexPath.row == 2)
            cell.hidden = YES;
        else if (self.message.userackDate == nil && indexPath.row == 3)
            cell.hidden = YES;
        else
            cell.hidden = NO;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.message.isOwn.boolValue) {
        if (self.message.remoteSentDate != nil && indexPath.row == 0)
            return UITableViewAutomaticDimension;
        else if (self.message.deliveryDate != nil && indexPath.row == 1)
            return UITableViewAutomaticDimension;
        else if (self.message.readDate != nil && indexPath.row == 2)
            return UITableViewAutomaticDimension;
        else if (indexPath.row == 4)
            return UITableViewAutomaticDimension;
        else
            return 0;
    } else {
        if (self.message.date == nil && indexPath.row == 0)
            return 0;
        if (self.message.deliveryDate == nil && indexPath.row == 1)
            return 0;
        if (self.message.readDate == nil && indexPath.row == 2)
            return 0;
        if (self.message.userackDate == nil && indexPath.row == 3)
            return 0;
    }
    
    return UITableViewAutomaticDimension;
}


@end
