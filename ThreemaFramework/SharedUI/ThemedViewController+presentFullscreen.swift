//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation

extension ThemedViewController {
    /// Present the provided image in a simple big view
    /// - Parameter image: Image to show in full screen
    public func presentFullscreen(image: UIImage) {
        guard let fullscreenImageViewController = FullscreenImageViewController(for: image) else {
            return
        }
        
        let modalNavigationController = ModalNavigationController(rootViewController: fullscreenImageViewController)
        modalNavigationController.showDoneButton = true
        
        if traitCollection.userInterfaceIdiom == .pad {
            modalNavigationController.showFullScreenOnIPad = true
        }
        else {
            modalNavigationController.modalPresentationStyle = .fullScreen
        }
        
        present(modalNavigationController, animated: true)
    }
}
