import Foundation
import UIKit

final class ProfileViewController: UIViewController {
    
    // MARK: - Properties
    
    let collectionView: ProfileCollectionView
    let dataSource: ProfileCollectionViewDataSource
    
    // MARK: - Lifecycle
    
    init(
        collectionView: ProfileCollectionView,
        dataSource: ProfileCollectionViewDataSource
    ) {
        self.collectionView = collectionView
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updateSelection()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        dataSource.configureData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dataSource.checkRevocationPassword()
        dataSource.checkEmailVerification()
    }

    // MARK: - Configuration
    
    private func configureView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    // MARK: - Updates
    
    func updateSelection() {
        collectionView.updateSelection()
    }
}
