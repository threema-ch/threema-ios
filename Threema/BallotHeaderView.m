//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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
#import "EntityManager.h"
#import "Contact.h"
#import "BundleUtil.h"
#import "AvatarMaker.h"

#define HEADER_BOUNCE_OFFSET 70.0

@implementation BallotHeaderView

- (void)awakeFromNib {
    [self setup];

    [super awakeFromNib];
}

- (void)setup {
    self.ddMainView = self.mainView;
    self.ddDetailView = self.accessoryView;
    
    self.imageView.layer.masksToBounds = YES;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.layer.cornerRadius = self.imageView.frame.size.width/2;
    
    self.bounceOffset = HEADER_BOUNCE_OFFSET;
    
    [self setupColors];
}

- (void)setupColors {
    _mainView.backgroundColor = [Colors background];
    _titleLabel.textColor = [Colors fontNormal];
    
    _accessoryView.backgroundColor = [Colors backgroundInverted];
    _createdByNameLabel.textColor = [Colors fontInverted];
    _dateLabel.textColor = [Colors fontInverted];
}

-(void)setBallot:(Ballot *)ballot {
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

    EntityManager *entityManager = [[EntityManager alloc] init];
    [_createdByNameLabel setText: [entityManager.entityFetcher displayNameForContactId: _ballot.creatorId]];
    
    Contact *creatorContact = [entityManager.entityFetcher contactForId:_ballot.creatorId];
    [_imageView setImage: [[AvatarMaker sharedAvatarMaker] avatarForContact:creatorContact size:_imageView.frame.size.width masked:NO]];
}
@end
