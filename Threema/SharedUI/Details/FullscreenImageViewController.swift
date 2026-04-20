import UIKit

final class FullscreenImageViewController: UIViewController {
    
    // MARK: - Properties

    private var controlsHidden = false

    private var image: UIImage
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.accessibilityIgnoresInvertColors = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()

    // MARK: - Lifecycle
    
    init(for image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationCapturesStatusBarAppearance = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
        controlsHidden
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tapGesture)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        tabBarController?.tabBar.isHidden = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        tabBarController?.tabBar.isHidden = false
    }
    
    // MARK: - Action

    @objc private func toggleControls() {
        controlsHidden.toggle()

        UIView.animate(withDuration: 0.2) {
            self.setNeedsStatusBarAppearanceUpdate()
            self.view.backgroundColor = self.controlsHidden ? .black : .systemGroupedBackground
            self.navigationController?.setNavigationBarHidden(self.controlsHidden, animated: true)
            self.tabBarController?.tabBar.alpha = self.controlsHidden ? 0.0 : 1.0
        }
    }
    
    // MARK: - Presentation helper
    
    static func present(for image: UIImage, on viewController: UIViewController) {
        let fullscreenImageViewController = FullscreenImageViewController(for: image)
        let navigationController = ModalNavigationController(rootViewController: fullscreenImageViewController)
        navigationController.showDoneButton = true
        
        if viewController.traitCollection.userInterfaceIdiom == .pad {
            navigationController.showFullScreenOnIPad = true
        }
        else {
            navigationController.modalPresentationStyle = .fullScreen
        }
        
        viewController.present(navigationController, animated: true)
    }
}

// MARK: Helper

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
