import CocoaLumberjackSwift
import UIKit
import UniformTypeIdentifiers

@MainActor
final class LocalBackupFilePicker: NSObject {

    /// Content types the picker offers.
    ///
    /// A backup is written as `*.dat` and `dat` is not a registered extension, so
    /// there is no backup specific type to filter on. The broadest data types are what reliably keeps the file
    /// selectable — at the cost of every other file being selectable too.
    private static let contentTypes: [UTType] = [.data, .item]

    private weak var presenter: UIViewController?
    private let onPicked: (URL) -> Void

    // MARK: - Lifecycle

    init(presenter: UIViewController?, onPicked: @escaping (URL) -> Void) {
        self.presenter = presenter
        self.onPicked = onPicked

        super.init()
    }

    func show() {

        // `asCopy: false` so the restore streams from the original file. The alternative, `asCopy: true`, drops a full
        // copy in `tmp/` first, which for a large backup means needing twice the space and waiting out the copy.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: Self.contentTypes, asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false

        presenter?.present(picker, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension LocalBackupFilePicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            DDLogWarn("[LocalBackupFilePicker] Picker finished without a URL")
            return
        }

        onPicked(url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        DDLogNotice("[LocalBackupFilePicker] Picking a local data backup was cancelled")
    }
}
