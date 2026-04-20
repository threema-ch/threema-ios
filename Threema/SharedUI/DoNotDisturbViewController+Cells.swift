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
            textLabel?.textColor = .systemRed
        }
    }
    
    final class PeriodButtonCell: ThemedCodeTableViewCell, Reusable {
        override func configureCell() {
            super.configureCell()
            
            textLabel?.textColor = .label
            
            accessibilityTraits.insert(.button)
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
    
    final class NotificationPlaySoundSettingCell: ThemedCodeTableViewCell, Reusable {
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
