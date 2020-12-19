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

#import <UIKit/UIKit.h>
#import "BallotChoice.h"

@class BallotCreateTableCell;

@protocol BallotCreateTableCellDelegate <NSObject>

- (void)didUpdateCell:(BallotCreateTableCell *)cell;
- (void)showPickerForCell:(BallotCreateTableCell *)cell;
- (void)hidePickerForCell:(BallotCreateTableCell *)cell;

@end

@interface BallotCreateTableCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UITextField *choiceTextField;
@property (weak, nonatomic) IBOutlet UIButton *dateButton;
@property (strong, nonatomic) UIDatePicker *datePicker;
@property (nonatomic, strong) UISwitch *allDaySwitch;

@property (nonatomic) BallotChoice *choice;

@property id<BallotCreateTableCellDelegate> delegate;

- (IBAction)showDatePicker:(id)sender;
- (void)setInputText:(NSDate *)date allDay:(BOOL)allDay;

@end
