import CocoaLumberjackSwift
import Combine
import Foundation
import GroupCalls
import SwiftUI
import ThreemaFramework
import UIKit

@objc final class StatusNavigationBar: UINavigationBar {
    
    // MARK: - Subviews
    
    private lazy var statusView = UIView(frame: CGRect(x: 0, y: frame.size.height - 2, width: frame.width, height: 2))
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(statusView)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        statusView.frame = CGRect(x: 0, y: frame.size.height - 2, width: frame.width, height: 2)
        updateNavigationBar()
    }
    
    private func configure() {
        ServerConnector.shared().registerConnectionStateDelegate(delegate: self)
        statusView.isHidden = true
        addSubview(statusView)
        updateStatusView()
        updateNavigationBar()
    }
    
    // MARK: - Private Functions
    
    private func updateNavigationBar() {
        Task { @MainActor in
            updateStatusView()
        }
    }
    
    @MainActor
    private func updateStatusView() {
        DispatchQueue.main.async { [self] in
            // The display of connection state is delayed because the process coordinator checks
            // whether it can establish a server connection, it takes a little longer to connect.
            var deadline: DispatchTime = .now()
            if statusView.isHidden {
                deadline = .now() + .seconds(1)
            }

            DispatchQueue.main.asyncAfter(deadline: deadline) { [self] in
                switch ServerConnector.shared().connectionState {
                case .disconnecting, .disconnected, .connecting:
                    if ProcessInfoHelper.isRunningForScreenshots {
                        statusView.backgroundColor = .systemGreen
                        statusView.isHidden = true
                    }
                    else {
                        statusView.backgroundColor = .systemRed
                        statusView.isHidden = AppDelegate.shared().isAppInBackground()
                    }

                case .connected:
                    statusView.backgroundColor = .systemOrange
                    statusView.isHidden = AppDelegate.shared().isAppInBackground()

                case .loggedIn:
                    statusView.backgroundColor = .systemGreen
                    statusView.isHidden = true
                }
            }
        }
    }
}

// MARK: - ConnectionStateDelegate

extension StatusNavigationBar: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        Task { @MainActor in
            updateStatusView()
        }
    }
}
