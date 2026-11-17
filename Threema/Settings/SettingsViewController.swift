import Foundation
import TipKit
import UIKit

final class SettingsViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var coordinator: SettingsCoordinator?
    
    private lazy var collectionView = SettingsCollectionView { [weak self] in
        self?.coordinator?.currentDestination
    } shouldAllowAutoDeselection: { [weak self] in
        self?.coordinator?.splitViewController.isCollapsed == true
    }

    private lazy var dataSource = SettingsCollectionViewDataSource(
        collectionView: collectionView,
        coordinator: coordinator
    )
    
    // MARK: TipKit

    private var betaFeedbackTip = TipKitManager.ThreemaBetaFeedbackTip()
    private var tipObservationTask: Task<Void, Never>?
    private weak var tipPopoverController: TipUIPopoverViewController?
    private var isVisible = false
    
    // MARK: - Lifecycle
    
    init(coordinator: SettingsCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        dataSource.configureData()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updateSelection()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        showBetaFeedbackTip()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isVisible = false
        removeTipObserver()
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        navigationController?.navigationBar.prefersLargeTitles = true

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
        collectionView.updateSelection(for: traitCollection.horizontalSizeClass)
    }
    
    private func showBetaFeedbackTip() {
        guard let cell = collectionView.betaFeedbackCell() else {
            return
        }
        
        tipObservationTask = tipObservationTask ?? Task { @MainActor in
            for await shouldDisplay in betaFeedbackTip.shouldDisplayUpdates {
                if shouldDisplay, isVisible {
                    let popoverController = TipUIPopoverViewController(betaFeedbackTip, sourceItem: cell)
                    present(popoverController, animated: true)
                    tipPopoverController = popoverController
                }
                else {
                    if presentedViewController is TipUIPopoverViewController {
                        tipPopoverController?.dismiss(animated: true)
                        tipPopoverController = nil
                    }
                }
            }
        }
    }
    
    private func removeTipObserver() {
        tipPopoverController?.dismiss(animated: false)
        tipObservationTask?.cancel()
        tipObservationTask = nil
    }
}
