import Foundation
import UIKit

final class MessageMarkersView: UIView {
    
    /// Message to show markers for
    ///
    /// Reset to update with current message information.
    var message: BaseMessageEntity? {
        didSet {
            guard let message else {
                return
            }
            updateMarkers(for: message)
        }
    }
        
    // MARK: - Private properties

    private lazy var markerStarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = UIImage(systemName: "star.fill")?.withTintColor(.systemYellow)
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        imageView.tintColor = .systemYellow
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var markerStarConstraints: [NSLayoutConstraint] = [
        markerStarImageView.topAnchor.constraint(equalTo: topAnchor),
        markerStarImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        markerStarImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        markerStarImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
    ]
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }
        
    convenience init() {
        self.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureLayout() {
        addSubview(markerStarImageView)
    }
    
    // MARK: - Updates
    
    private func updateMarkers(for message: BaseMessageEntity) {
        guard message.hasMarkers else {
            markerStarImageView.isHidden = true
            NSLayoutConstraint.deactivate(markerStarConstraints)
            return
        }
        
        NSLayoutConstraint.activate(markerStarConstraints)
        markerStarImageView.isHidden = false
    }
}
