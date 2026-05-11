import Foundation
import TipKit
import UIKit

final class ProfileViewController: UIViewController {
    
    // MARK: - Properties
    
    let collectionView: ProfileCollectionView
    let dataSource: ProfileCollectionViewDataSource
    
    // MARK: TipKit

    private var workAvailabilityStatusTip = TipKitManager.ThreemaWorkAvailabilityStatusChatTip(forChat: false)
    private var tipObservationTask: Task<Void, Never>?
    private weak var tipPopoverController: TipUIPopoverViewController?
    
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
        showWorkAvailabilityStatusTip()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeTipObserver()
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
    
    private func showWorkAvailabilityStatusTip() {
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }
        
        guard ThreemaEnvironment.workAvailabilityStatusEnabled else {
            return
        }
        
        guard let cell = collectionView.workAvailabilityStatusCell() else {
            return
        }
        
        tipObservationTask = tipObservationTask ?? Task { @MainActor in
            for await shouldDisplay in workAvailabilityStatusTip.shouldDisplayUpdates {
                if shouldDisplay {
                    let popoverController = TipUIPopoverViewController(workAvailabilityStatusTip, sourceItem: cell)
                    present(popoverController, animated: true)
                    tipPopoverController = popoverController
                }
                else {
                    if presentedViewController is TipUIPopoverViewController {
                        dismiss(animated: true)
                        tipPopoverController = nil
                    }
                }
            }
        }
    }
    
    private func removeTipObserver() {
        tipObservationTask?.cancel()
        tipObservationTask = nil
    }
}
