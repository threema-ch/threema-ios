//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "BallotCreateTableCell.h"
#import "UIImage+ColoredImage.h"
#import "BundleUtil.h"

@interface BallotCreateTableCell () <UITextFieldDelegate>

@property (nonatomic, strong) UILabel *allDayLabel;

@end

@implementation BallotCreateTableCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [_choiceTextField setPlaceholder:[BundleUtil localizedStringForKey:@"ballot_placeholder_choice"]];
    
    _choiceTextField.delegate = self;
    
    [Colors updateKeyboardAppearanceFor:_choiceTextField];
    
    [_dateButton setImage:[UIImage imageNamed:@"Calendar" inColor:Colors.primary] forState:UIControlStateNormal];
    
    [_dateButton setAccessibilityLabel:[BundleUtil localizedStringForKey:@"ballot_date_button"]];
}

- (void)setChoiceText:(NSString *)text {
    [_choiceTextField setText: text];
}

- (void)didChangeChoiseText:(NSString *)text {
    if (_delegate) {
        [_delegate didChangeChoiseText:text on:self];
    }
}

- (void)didEnterChoiceText {
    if (_delegate) {
        [_delegate didUpdateCell: self];
    }
}

- (void)dateChanged {
    [self setTextForChoiceField];
}

- (void)setTextForChoiceField {
    if (_allDaySwitch.on) {
        _choiceTextField.text = [NSString stringWithFormat:@"%@", [DateFormatter getDayMonthAndYear:_datePicker.date]];
    } else {
        if (@available(iOS 14.0, *)) {
            // do not round the time for iOS 14
        } else {
            NSTimeInterval seconds = ceil([_datePicker.date timeIntervalSinceReferenceDate]/300.0)*300.0;
            _datePicker.date = [NSDate dateWithTimeIntervalSinceReferenceDate:seconds];
        }
        _choiceTextField.text = [NSString stringWithFormat:@"%@", [DateFormatter getFullDateFor:_datePicker.date]];
    }

    [self didChangeChoiseText:_choiceTextField.text];
}

- (void)changePickerMode:(id)sender {
    UISwitch *allDaySwitch = (UISwitch *)sender;
    CGFloat timeLabelHeight = 38.0;
    if (_allDaySwitch.on) {
        _datePicker.datePickerMode = UIDatePickerModeDate;
        if (@available(iOS 14.0, *)) {
            _datePicker.frame = CGRectMake(_datePicker.frame.origin.x, _datePicker.frame.origin.y, _datePicker.frame.size.width, _datePicker.frame.size.height - timeLabelHeight);
        }
    } else {
        _datePicker.datePickerMode = UIDatePickerModeDateAndTime;
        if (@available(iOS 14.0, *)) {
            if (allDaySwitch != nil) {
                _datePicker.frame = CGRectMake(_datePicker.frame.origin.x, _datePicker.frame.origin.y, _datePicker.frame.size.width, _datePicker.frame.size.height + timeLabelHeight);
            }
        }
    }
    if (_choiceTextField.text.length) {
        [self setTextForChoiceField];
    }
}

- (void)setInputText:(NSDate *)date allDay:(BOOL)allDay {
    NSDate *timeDate = [DateFormatter getDateFromFullDateString:_choiceTextField.text];
    NSDate *normalDate = [DateFormatter getDateFromDayMonthAndYearDateString:_choiceTextField.text];
    
    if (timeDate == nil && normalDate == nil) {
        _datePicker.date = date;
        if (allDay) {
            _datePicker.datePickerMode = UIDatePickerModeDate;
        } else {
            _datePicker.datePickerMode = UIDatePickerModeDateAndTime;
        }
        
        _allDaySwitch.on = allDay;
    }
    
   [self setTextForChoiceField];
}

- (void)addPicker {
    if (@available(iOS 14.0, *)) {
        self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, _choiceTextField.frame.origin.y + _choiceTextField.frame.size.height + 8.0, self.contentView.frame.size.width, 355.0)];
    } else {
        self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0.0, _choiceTextField.frame.origin.y + _choiceTextField.frame.size.height, self.contentView.frame.size.width, 216.0)];
    }

    if (@available(iOS 14.0, *)) {
        _datePicker.minuteInterval = 1;
        _datePicker.preferredDatePickerStyle = UIDatePickerStyleInline;
    } else {
        _datePicker.minuteInterval = 5;
    }
    [_datePicker setValue:Colors.primary forKey:@"textColor"];
    [_datePicker addTarget:self action:@selector(dateChanged) forControlEvents:UIControlEventValueChanged];
    _datePicker.alpha = 0.0;
    [self addSubview:_datePicker];
    
    CGFloat space = 0.0;
    if (@available(iOS 14.0, *)) {
        space = 8.0;
    }
    
    _allDayLabel = [[UILabel alloc] initWithFrame:CGRectMake(_choiceTextField.frame.origin.x, _datePicker.frame.origin.y + _datePicker.frame.size.height + space, _choiceTextField.frame.size.width, 31.0)];
    _allDayLabel.text = [BundleUtil localizedStringForKey:@"ballot_allDay_switch"];
    _allDayLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [_allDayLabel setValue:Colors.text forKey:@"textColor"];
    _allDayLabel.alpha = 0.0;
    [_allDayLabel setIsAccessibilityElement:NO];
    [_allDayLabel setAccessibilityElementsHidden:YES];
    [self addSubview:_allDayLabel];
    
    _allDaySwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.frame.size.width - 20.0 - 51.0, _datePicker.frame.origin.y + _datePicker.frame.size.height + space, 51.0, 31.0)];
    [_allDaySwitch addTarget:self action:@selector(changePickerMode:) forControlEvents:UIControlEventValueChanged];
    _allDaySwitch.alpha = 0.0;
    _allDaySwitch.accessibilityLabel = [BundleUtil localizedStringForKey:@"ballot_allDay_switch"];
    [self addSubview:_allDaySwitch];
    
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}
#pragma mark - text field delegate

-(void)textFieldDidEndEditing:(UITextField *)textField {
    [self didChangeChoiseText:textField.text];
    [self didEnterChoiceText];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self didChangeChoiseText:textField.text];
    [self didEnterChoiceText];
    
    return YES;
}

// track any changes
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self didChangeChoiseText:newValue];

    return YES;
}

#pragma mark - Actions

- (IBAction)showDatePicker:(id)sender {
    if (!_datePicker && !self.editing) {
        [self addPicker];
        
        NSDate *selectedDate = [DateFormatter getDateFromFullDateString:_choiceTextField.text];
        if (selectedDate != nil) {
            _datePicker.date = selectedDate;
            _allDaySwitch.on = false;
        } else {
            selectedDate =  [DateFormatter getDateFromDayMonthAndYearDateString:_choiceTextField.text];
            if (selectedDate != nil) {
                _datePicker.date = selectedDate;
                _allDaySwitch.on = true;
            }
        }
        
        [self changePickerMode:nil];
        
        [_delegate showPickerForCell:self];
        [UIView animateWithDuration:0.35 animations:^{
            _datePicker.alpha = 1.0;
            _allDaySwitch.alpha = 1.0;
            _allDayLabel.alpha = 1.0;
        } completion:^(BOOL finished) {
            [_datePicker setIsAccessibilityElement:YES];
            [_datePicker setAccessibilityElementsHidden:NO];
            [_allDaySwitch setIsAccessibilityElement:YES];
            [_allDaySwitch setAccessibilityElementsHidden:NO];
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
        }];
    } else {
        [_delegate hidePickerForCell:self];
        
        [UIView animateWithDuration:0.2 animations:^{
            _datePicker.alpha = 0.0;
            _allDaySwitch.alpha = 0.0;
            _allDayLabel.alpha = 0.0;
        } completion:^(BOOL finished) {
            [_datePicker removeFromSuperview];
            [_allDaySwitch removeFromSuperview];
            [_allDayLabel removeFromSuperview];
            _datePicker = nil;
        }];
    }
}

@end
