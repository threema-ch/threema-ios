//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import "BallotHeaderView.h"
#import "EntityFetcher.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "ThreemaFramework.h"

#define HEADER_BOUNCE_OFFSET 70.0

@implementation BallotHeaderView

- (void)awakeFromNib {
    [self setup];

    [super awakeFromNib];
}

- (void)setup {
    self.ddMainView = self.mainView;
    self.ddDetailView = self.accessoryView;

    self.bounceOffset = HEADER_BOUNCE_OFFSET;
    
    _mainView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    _accessoryView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    _titleLabel.textColor = UIColor.labelColor;
    _createdByNameLabel.textColor = UIColor.secondaryLabelColor;
    _dateLabel.textColor = UIColor.secondaryLabelColor;
    _hairLineView.backgroundColor = UIColor.placeholderTextColor;
}

-(void)setBallot:(BallotEntity *)ballot {
    _ballot = ballot;
    
    [_titleLabel setText: ballot.title];
    
    [self updateDate];
    
    [self updateContact];
}

-(void)updateDate {
    NSDate *date = _ballot.modifyDate;
    if (date == nil) {
        date = _ballot.createDate;
    }
    
    [_dateLabel setText: [DateFormatter shortStyleDateTime: date]];
}

-(void)updateContact {
    if (_ballot.creatorId == nil) {
        return;
    }

    BusinessInjector *businessInjector = [BusinessInjector new];
    EntityManager *entityManager = businessInjector.entityManager;
    [_createdByNameLabel setText: [entityManager.entityFetcher displayNameForContactId: _ballot.creatorId]];
    
    ContactEntity *creatorContact = [entityManager.entityFetcher contactForId:_ballot.creatorId];
    
    if (creatorContact != nil) {
        [_profilePictureView setContactWithContact:[[Contact alloc]initWithContactEntity:creatorContact]];
    } else {
        // No contact found, so we assume we are the creator
        [_profilePictureView setMe];
    }
}
@end
