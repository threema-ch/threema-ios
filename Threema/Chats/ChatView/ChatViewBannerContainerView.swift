import UIKit

/// Container view that manages multiple banner views in the chat
/// Banners are stacked vertically and can be shown/hidden independently
final class ChatViewBannerContainerView: UIView {
    
    // MARK: - Properties
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Track registered banners
    private var registeredBanners: [UIView] = []
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }
    
    deinit {
        for banner in registeredBanners {
            banner.removeObserver(self, forKeyPath: "hidden")
        }
    }
    
    // MARK: - KVO
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "hidden" {
            updateContainerVisibility(animated: true)
        }
    }
    
    // MARK: - Setup
    
    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        // Container is hidden when no banners are visible
        isHidden = true
    }
    
    // MARK: - Banner Management
    
    /// Adds a banner view to the container
    /// - Parameter banner: The banner view to add
    func addBanner(_ banner: UIView) {
        guard !registeredBanners.contains(banner) else {
            return
        }
        
        registeredBanners.append(banner)
        stackView.addArrangedSubview(banner)
        
        // Observe banner's isHidden property to update container visibility
        banner.addObserver(self, forKeyPath: "hidden", options: [.new, .old], context: nil)
        
        updateContainerVisibility()
    }
    
    /// Removes a banner view from the container
    /// - Parameter banner: The banner view to remove
    func removeBanner(_ banner: UIView) {
        guard let index = registeredBanners.firstIndex(of: banner) else {
            return
        }
        
        banner.removeObserver(self, forKeyPath: "hidden")
        registeredBanners.remove(at: index)
        stackView.removeArrangedSubview(banner)
        banner.removeFromSuperview()
        
        updateContainerVisibility()
    }
    
    // MARK: - Private
    
    private func updateContainerVisibility(animated: Bool = false) {
        let hasVisibleBanner = registeredBanners.contains { !$0.isHidden }
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.isHidden = !hasVisibleBanner
                self.alpha = hasVisibleBanner ? 1.0 : 0.0
            }
        }
        else {
            isHidden = !hasVisibleBanner
            alpha = hasVisibleBanner ? 1.0 : 0.0
        }
    }
}

#if DEBUG

    #Preview {
        let banner1 = UILabel()
        banner1.text = "Banner 1"
        banner1.backgroundColor = .red
        let banner2 = UILabel()
        banner2.text = "Banner 2"
        banner2.backgroundColor = .green

        let view = ChatViewBannerContainerView(frame: .zero)
        view.addBanner(banner1)
        view.addBanner(banner2)

        view.sizeToFit()

        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            banner2.isHidden = true

            try await Task.sleep(nanoseconds: 2_000_000_000)
            banner1.isHidden = true
        }

        return view
    }

#endif
