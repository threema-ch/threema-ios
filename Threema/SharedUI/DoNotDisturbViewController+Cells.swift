//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

extension DoNotDisturbViewController {
    
    final class ActiveDNDInfoCell: ThemedCodeTableViewCell, Reusable {
        override func configureCell() {
            super.configureCell()
            
            selectionStyle = .none
            separatorInset = .zero
        }
    }
    
    final class TurnOffDNDButtonCell: ThemedCodeTableViewCell, Reusable {
        override func configureCell() {
            super.configureCell()
            
            accessibilityTraits.insert(.button)
            textLabel?.textAlignment = .center
        }
        
        override func updateColors() {
            super.updateColors()
            
            Colors.setTextColor(Colors.red, in: self)
        }
    }
    
    final class PeriodButtonCell: ThemedCodeTableViewCell, Reusable {
        override func configureCell() {
            super.configureCell()
            
            accessibilityTraits.insert(.button)
        }
        
        override func updateColors() {
            super.updateColors()
            // Even tough they are buttons don't use the accent color. Just for stylistic reasons.
            Colors.setTextColor(Colors.text, in: self)
        }
    }
    
    final class NotifyWhenMentionedSettingCell: ThemedCodeTableViewCell, Reusable {
        /// Set initial state
        var isOn: Bool {
            set {
                switchControl.isOn = newValue
            }
            get {
                switchControl.isOn
            }
        }
        
        /// Called whenever the switch changes values
        var valueDidChange: ((Bool) -> Void)?
        
        private let switchControl = UISwitch()
        
        override func configureCell() {
            super.configureCell()
            
            selectionStyle = .none
            accessoryView = switchControl
            
            switchControl.addTarget(self, action: #selector(switchDidChange(sender:)), for: .touchUpInside)
        }
        
        override func prepareForReuse() {
            super.prepareForReuse()
            
            valueDidChange = nil
        }
        
        @objc private func switchDidChange(sender: UISwitch) {
            valueDidChange?(sender.isOn)
        }
    }
}
