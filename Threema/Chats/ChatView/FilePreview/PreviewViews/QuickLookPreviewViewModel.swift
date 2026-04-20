import Combine
import FileUtility
import ThreemaFramework
import ThreemaMacros

@MainActor
final class QuickLookPreviewViewModel: ObservableObject {
    @Published private(set) var tempFileURL: URL?
    
    let fileMessageEntity: FileMessageEntity
    
    var shouldShowPreview: Bool {
        tempFileURL != nil
    }
    
    private(set) var doneButtonTitle = #localize("Done")
    
    let fileUtility: FileUtilityProtocol
    
    init(
        fileMessageEntity: FileMessageEntity,
        fileUtility: FileUtilityProtocol = FileUtility.shared
    ) {
        self.fileMessageEntity = fileMessageEntity
        self.fileUtility = fileUtility
    }
    
    func load() {
        prepareFile()
    }
    
    func onDisappear() {
        cleanupTempFile()
    }
    
    private func prepareFile() {
        let filename = fileUtility.getTemporarySendableFileName(base: "file")
        let tmpURL = fileMessageEntity.tempFileURL(fallBackFileName: filename)
        
        fileMessageEntity.exportData(to: tmpURL)
        tempFileURL = tmpURL
    }
    
    private func cleanupTempFile() {
        guard let url = tempFileURL else {
            return
        }
        
        do {
            try fileUtility.delete(at: url)
            tempFileURL = nil
        }
        catch {
            print("Failed to cleanup temp file: \(error)")
        }
    }
}
