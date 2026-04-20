import UIKit

final class StyleKitDebugViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scrollView = UIScrollView()
        let debugStackView = StyleKit.debugStackView()
        
        scrollView.addSubview(debugStackView)
        view.addSubview(scrollView)
        
        debugStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            debugStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            debugStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            debugStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            debugStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}
