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
        let mime = fileMessageEntity.mimeType ?? ""
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
                            DoneButton {
                                dismiss()
                            }
                        }
                    }
                }
        }
    }
}
