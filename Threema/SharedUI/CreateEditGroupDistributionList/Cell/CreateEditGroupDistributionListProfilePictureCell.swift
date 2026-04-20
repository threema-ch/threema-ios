final class CreateEditGroupDistributionListProfilePictureCell: UICollectionViewCell {
    // MARK: - Private properties

    private var containedView: UIView?
    
    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        containedView?.removeFromSuperview()
        containedView = nil
        
        super.prepareForReuse()
    }
    
    // MARK: Configuration

    func configure(view: UIView?) {
        containedView = view
        
        guard let view else {
            return
        }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentView.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}

// MARK: - Reusable

extension CreateEditGroupDistributionListProfilePictureCell: Reusable { }
