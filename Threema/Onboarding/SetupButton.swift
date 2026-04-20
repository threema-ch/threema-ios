import UIKit

@IBDesignable final class SetupButton: UIButton {
    
    @IBInspectable var cancelStyle = false {
        didSet {
            setup()
        }
    }
    
    @IBInspectable var accentColor: UIColor = .tintColor {
        didSet {
            setup()
        }
    }
    
    @IBInspectable var textColor: UIColor = Colors.textSetup {
        didSet {
            setup()
        }
    }
    
    var deactivated: Bool {
        set {
            isEnabled = !newValue
            setup()
        }
        get {
            isEnabled
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        titleLabel?.font = UIFont.systemFont(ofSize: 16.0)

        alpha = isEnabled ? 1.0 : 0.5
        isUserInteractionEnabled = isEnabled
        layer.cornerRadius = 3
        addConstraint(NSLayoutConstraint(
            item: self,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 0.0,
            constant: 36
        ))
        
        // Calculate disabled color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        let resolvedAccentColor = accentColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        resolvedAccentColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        let resolvedAccentColorDisabled = UIColor(red: red, green: green, blue: blue, alpha: 0.5)

        if cancelStyle {
            backgroundColor = .clear
            setTitleColor(resolvedAccentColor, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = isEnabled ? resolvedAccentColor.cgColor : resolvedAccentColorDisabled.cgColor
        }
        else {
            backgroundColor = isEnabled ? resolvedAccentColor : resolvedAccentColorDisabled
            setTitleColor(Colors.textProminentButtonWizard, for: .normal)
        }
    }
}
