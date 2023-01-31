//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

protocol MediaPreviewItemProtocol: PreviewItemProtocol {
    var thumbnail: Promise<UIImage> { get }
    func freeMemory()
}

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
        guard let itemURL = itemURL else {
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
    
    public lazy var itemQueue = DispatchQueue(label: "ch.threema.mediaPreviewItemQueue", attributes: .concurrent)
    
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
        do {
            try FileManager.default.removeItem(at: url)
        }
        catch {
            DDLogError("Could not remove item because \(error.localizedDescription)")
        }
    }
    
    func freeMemory() {
        internalThumbnail = nil
    }
}
