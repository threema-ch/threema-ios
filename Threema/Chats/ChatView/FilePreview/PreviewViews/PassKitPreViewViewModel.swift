import PassKit
import ThreemaFramework

@MainActor
final class PassKitPreviewViewModel: ObservableObject {
    @Published private(set) var pkPass: PKPass?
    @Published private(set) var hasFailed = false
    
    let fileMessageEntity: FileMessageEntity
    
    var shouldShowPass: Bool {
        pkPass != nil
    }
    
    var shouldShowFailure: Bool {
        hasFailed
    }
    
    init(fileMessageEntity: FileMessageEntity) {
        self.fileMessageEntity = fileMessageEntity
    }
    
    func loadPass() {
        guard let passData = fileMessageEntity.data?.data else {
            hasFailed = true
            return
        }
        
        do {
            pkPass = try PKPass(data: passData)
        }
        catch {
            hasFailed = true
        }
    }
}
