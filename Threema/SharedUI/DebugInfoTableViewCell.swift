import UIKit

/// Show debug info in a text view
final class DebugInfoTableViewCell: ThemedCodeTableViewCell {
    
    var debugText: String? {
        didSet {
            debugTextView.text = debugText
        }
    }
    
    private lazy var debugTextView: UITextView = {
        let textView = UITextView()
        
        textView.isScrollEnabled = false
        textView.isEditable = false
        
        return textView
    }()
    
    override func configureCell() {
        super.configureCell()

        selectionStyle = .none
        
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 5,
            leading: 5,
            bottom: 5,
            trailing: 5
        )
        
        contentView.addSubview(debugTextView)
        debugTextView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            debugTextView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            debugTextView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            debugTextView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            debugTextView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }
    
    override func updateColors() {
        super.updateColors()
        
        debugTextView.backgroundColor = .secondarySystemGroupedBackground
    }
}

// MARK: - Reusable

extension DebugInfoTableViewCell: Reusable { }
