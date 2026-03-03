//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import FileUtility
import SwiftUI
import ThreemaMacros

struct FileMessagePreviewView: View {
    
    enum PreviewType {
        case quickLook, contact, pass
    }
    
    @Environment(\.dismiss) private var dismiss
    
    let fileMessageEntity: FileMessageEntity
    
    @StateObject private var quickLookPreviewViewModel: QuickLookPreviewViewModel
    @StateObject private var contactPreviewViewModel: ContactPreviewViewModel
    @StateObject private var passKitPreviewViewModel: PassKitPreviewViewModel
    
    init(fileMessageEntity: FileMessageEntity) {
        self.fileMessageEntity = fileMessageEntity
        
        _quickLookPreviewViewModel = StateObject(
            wrappedValue: QuickLookPreviewViewModel(
                fileMessageEntity: fileMessageEntity
            )
        )
        
        _contactPreviewViewModel = StateObject(
            wrappedValue: ContactPreviewViewModel(
                fileMessageEntity: fileMessageEntity,
                authorizationStatus: {
                    CNContactStore.authorizationStatus(for: $0)
                },
                requestContactAccess: {
                    try await CNContactStore().requestAccess(for: $0)
                }
            )
        )
        
        _passKitPreviewViewModel = StateObject(
            wrappedValue: PassKitPreviewViewModel(
                fileMessageEntity: fileMessageEntity
            )
        )
    }

    var body: some View {
        preview
    }
    
    @ViewBuilder
    var preview: some View {
        switch previewType {
        case .quickLook:
            QuickLookPreviewView(viewModel: quickLookPreviewViewModel)

        case .contact:
            withWithNavigation {
                ContactPreviewView(viewModel: contactPreviewViewModel)
            }

        case .pass:
            withWithNavigation(hasToolbar: false) {
                PassKitPreviewView(viewModel: passKitPreviewViewModel)
            }
        }
    }
    
    private var previewType: PreviewType {
        let mime = fileMessageEntity.mimeType
        if UTIConverter.isContactMimeType(mime) {
            return .contact
        }
        else if UTIConverter.isPassMimeType(mime) {
            return .pass
        }
        else {
            return .quickLook
        }
    }
    
    @ViewBuilder
    func withWithNavigation(hasToolbar: Bool = true, @ViewBuilder content: () -> some View) -> some View {
        NavigationView {
            content()
                .navigationViewStyle(.stack)
                .navigationBarTitleDisplayMode(.inline)
                .applyIf(hasToolbar) { view in
                    view.toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(#localize("Done")) {
                                dismiss()
                            }
                        }
                    }
                }
        }
    }
}
