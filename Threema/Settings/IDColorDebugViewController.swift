import ThreemaFramework
import UIKit

final class IDColorDebugViewController: UIViewController {

    private let labelText = "Emily Yeung"
    
    private lazy var debugStackView: UIStackView = {
        let stack = UIStackView()
        
        for color in UIColor.IDColor.debugColors {
            let label = label(with: color)
            stack.addArrangedSubview(label)
            
            let line = line(with: color)
            stack.addArrangedSubview(line)
        }
        
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        stack.isLayoutMarginsRelativeArrangement = true
                    
        stack.backgroundColor = .chatBubbleReceived
        
        return stack
    }()
    
    private lazy var debugStackView2: UIStackView = {
        let stack = UIStackView()
        
        for color in UIColor.IDColor.debugColors {
            let label = label(with: color)
            stack.addArrangedSubview(label)
            
            let line = line(with: color)
            stack.addArrangedSubview(line)
        }
        
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        stack.isLayoutMarginsRelativeArrangement = true
               
        stack.backgroundColor = .chatBubbleSent
        
        return stack
    }()
    
    private lazy var containerStack = UIStackView(arrangedSubviews: [
        debugStackView,
        debugStackView2,
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let scrollView = UIScrollView()
        scrollView.addSubview(containerStack)
        view.addSubview(scrollView)
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    private func label(with color: UIColor) -> UILabel {
        let label = UILabel()
        
        label.text = labelText
        label.textColor = color
        
        return label
    }
    
    private func line(with color: UIColor) -> UIView {
        let view = UIView()
        
        view.backgroundColor = color
        
        view.heightAnchor.constraint(equalToConstant: 2).isActive = true
        view.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        return view
    }
}
