import CocoaLumberjackSwift
import FileUtility
import Foundation
import PromiseKit

@objc open class MediaPreviewItem: NSObject {
    public enum LoadError: Error {
        case unknown
        case memoryConstrained
        case osNotSupported
        case notAvailable
    }
    
    // MARK: - Public Properties

    open var filename: String?
    
    open var uti: String? {
        guard let itemURL else {
            return nil
        }
        return UTIConverter.uti(forFileURL: itemURL)
    }
    
    open var internalThumbnail: UIImage?
    open var originalAsset: Any?
    
    public var memoryConstrained = true
    public var itemURL: URL?
    
    public var sendAsFile = false
    public var caption: String?
    
    public private(set) lazy var itemQueue = DispatchQueue(
        label: "ch.threema.mediaPreviewItemQueue",
        attributes: .concurrent
    )
    
    lazy var estimatedFileSize: Double = {
        guard let itemURL = self.itemURL else {
            return CGFloat.greatestFiniteMagnitude
        }

        guard let resources = try? itemURL.resourceValues(forKeys: [.fileSizeKey]) else {
            return CGFloat.greatestFiniteMagnitude
        }
        
        guard let fileSize = resources.fileSize else {
            return CGFloat.greatestFiniteMagnitude
        }
        
        return Double(fileSize)
    }()
    
    open var thumbnail: Promise<UIImage> {
        Promise { $0.reject(LoadError.notAvailable) }
    }
    
    // MARK: Lifecycle

    override public init() {
        super.init()
    }
    
    init(itemURL: URL) {
        self.itemURL = itemURL
    }
    
    func getAccessibilityDescription() -> String? {
        nil
    }
    
    func removeItem() {
        guard let url = itemURL else {
            return
        }
        
        FileUtility.shared.deleteIfExists(at: url)
    }
    
    open func freeMemory() {
        filename = nil
        internalThumbnail = nil
    }
}
