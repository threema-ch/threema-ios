//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import PromiseKit

@objc public class ItemLoader: NSObject {
    @objc public enum ItemType: Int {
        case TextOnly
        case Media
    }
    
    public enum TextFileLoaderError: Error {
        case HiddenTextFileError
    }
    
    private enum ItemLoaderError: Error {
        case UnknownType
    }
    
    public var itemsToSend: Set<IntermediateItem> = Set()
    
    private let fileOperationQueue = DispatchQueue(label: "fileOperationQueue", qos: .userInitiated)
    private let forceLoadFileURLItem: Bool
    private let tmpDirURL: URL
    
    override public convenience init() {
        self.init(forceLoadFileURLItem: false)
    }
    
    @objc public init(forceLoadFileURLItem: Bool) {
        self.forceLoadFileURLItem = forceLoadFileURLItem
        self.tmpDirURL = ItemLoader.getTemporaryDirectory()
    }
    
    @objc public func syncLoadContentItems() -> [Any]? {
        let sema = DispatchSemaphore(value: 0)
        filterContentItems()
        var finalItems: [Any]?
        _ = loadItems().done(on: DispatchQueue.global(qos: .userInteractive)) { items in
            finalItems = items
            sema.signal()
        }.catch { error in
            DDLogError("Could not load items because \(error)")
            sema.signal()
        }
        sema.wait()
        return finalItems
    }
    
    private static func getTemporaryDirectory() -> URL {
        var url: URL
        var exists = true
        repeat {
            url = FileManager.default.temporaryDirectory.appendingPathComponent("\(Int.random(in: 0...32768))")
            exists = FileManager.default.fileExists(atPath: url.absoluteString)
        }
        while exists
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            DDLogError("Error occured while creating temporary directory. Error: \(error)")
        }
        
        return url
    }
    
    public func deleteTempDir() {
        do {
            try FileManager.default.removeItem(at: tmpDirURL)
        }
        catch {
            DDLogError("Could not remove temporary directory!")
        }
    }
    
    public func loadItems() -> Promise<[Any]> {
        var items = [Promise<Any>]()
        for intermediaryItem in itemsToSend {
            items.append(loadItem(intermediaryItem))
        }
        return when(fulfilled: items)
    }
    
    @objc public func checkItemType() -> ItemType {
        for item in itemsToSend {
            if isTextItem(item: item) {
                return .TextOnly
            }
        }
        return .Media
    }
    
    private func isTextItem(item: IntermediateItem) -> Bool {
        let firstType = item.type
        let checkedType = checkSecondaryType(item)
        
        let isText = UTIConverter.type(checkedType, conformsTo: kUTTypePlainText as String)
        let isURL = UTIConverter.type(checkedType, conformsTo: kUTTypeURL as String)
        
        let firstTypeIsFileURL = UTIConverter.type(firstType, conformsTo: kUTTypeFileURL as String)
        let secondTypeIsFileURL = UTIConverter.type(checkedType, conformsTo: kUTTypeFileURL as String)
        let anyTypeIsFileURL = firstTypeIsFileURL || secondTypeIsFileURL
        
        return (isText || isURL) && !anyTypeIsFileURL
    }
    
    private func getTextItems(items: Set<IntermediateItem>) -> Set<IntermediateItem> {
        items.filter { self.isTextItem(item: $0) }
    }
    
    private func getContentItems(items: Set<IntermediateItem>) -> Set<IntermediateItem> {
        items.filter { UTIConverter.type(checkSecondaryType($0), conformsTo: kUTTypeContent as String) }
    }
    
    public func filterContentItems() {
        itemsToSend = getContentItems(items: itemsToSend)
    }
    
    public func filterTextItems() {
        itemsToSend = getTextItems(items: itemsToSend)
    }
    
    public func generatePreviewText(items: Promise<[Any]>) -> Promise<(String, NSRange?)> {
        items.then { results -> Promise<(String, NSRange?)> in
            
            if results.count == 1, let firstURL = results.first as? URL, firstURL.isFileURL {
                return .init(error: TextFileLoaderError.HiddenTextFileError)
            }
            
            let sorted = results.sorted { left, _ -> Bool in
                left is URL
            }
            let reversed = self.markTextContent(sorted)
            let text = reversed.text
            let startPosition = reversed.startPosition
            
            var range: NSRange?
            
            if startPosition != text.count {
                range = NSRange(location: startPosition, length: text.count - startPosition)
            }
            
            return .value((text, range))
        }
    }
    
    /// Adds the strings or urls from reversed results
    /// - Parameter results: An array of containing String and/or URL
    /// - Returns: The strings and/or URls in a single String and the start position of the second item; or -1 if there
    ///            is no second item
    public func markTextContent(_ results: [Any]) -> (text: String, startPosition: Int) {
        var text = ""
        var startPosition = -1
        for result in results {
            if result is String {
                text.append(result as! String)
            }
            else if result is URL {
                if (result as! URL).isFileURL {
                    continue
                }
                text.append((result as! URL).absoluteString)
            }
            else {
                let err = "Generating a preview text from an item that is not a string or an url is not allowed"
                DDLogError(err)
                fatalError(err)
            }
            text.append("\n")
            
            if startPosition == -1 {
                startPosition = text.count
            }
        }
        return (text, startPosition)
    }
    
    @objc public func addItem(itemProvider: NSItemProvider, type: String, secondType: String?) {
        let item = IntermediateItem(itemProvider: itemProvider, type: type, secondType: secondType, caption: nil)
        itemsToSend.insert(item)
    }
    
    private func copyItem(at: URL, to: URL) -> (Bool, Error?) {
        do {
            try FileManager.default.copyItem(at: at, to: to)
        }
        catch {
            return (false, error)
        }
        return (true, nil)
    }
    
    private func checkSecondaryType(_ intermediateItem: IntermediateItem) -> String {
        let chooseSecondType = [
            "com.apple.live-photo",
            "com.apple.avfoundation.urlasset",
            "com.apple.mobileslideshow.asset.localidentifier",
            "com.compuserve.gif",
            "public.file-url",
            "public.url",
            "com.apple.is-remote-clipboard",
            // Copied to clipboard with shortcuts automation
            "link.contentkit.cachingidentifier",
        ]
        
        if chooseSecondType.contains(where: { $0 == intermediateItem.type }),
           let secondType = intermediateItem.secondType {
            return secondType
        }
        
        return intermediateItem.type
    }
    
    private func loadItem(_ intermediateItem: IntermediateItem) -> Promise<Any> {
        let type = checkSecondaryType(intermediateItem)
        if checkItemType() == .Media {
            return Promise { seal in
                let isFileItem = intermediateItem.itemProvider
                    .hasItemConformingToTypeIdentifier(kUTTypeFileURL as String)
                let isContent = intermediateItem.itemProvider
                    .hasItemConformingToTypeIdentifier(kUTTypeContent as String)
                if (isFileItem && isContent) || forceLoadFileURLItem {
                    intermediateItem.itemProvider.loadFileRepresentation(forTypeIdentifier: type) { item, error in
                        if let error {
                            seal.reject(error)
                        }
                        if let urlItem = item, urlItem.scheme == "file" {
                            self.loadURLItem(urlItem: urlItem, type: type, seal: seal)
                        }
                    }
                }
                else {
                    self.loadGeneralURLItem(intermediateItem: intermediateItem, type: type, seal: seal)
                }
            }
        }
        return loadGeneralURLItem(intermediateItem)
    }
    
    private func loadDataRepresentation(_ intermediateItem: IntermediateItem, type: String, seal: Resolver<Any>) {
        intermediateItem.itemProvider.loadDataRepresentation(forTypeIdentifier: type) { item, error in
            if let error {
                seal.reject(error)
            }
            if let dataItem = item {
                self.loadDataItem(dataItem: dataItem, type: type, seal: seal)
            }
        }
    }
    
    private func loadGeneralURLItem(_ intermediateItem: IntermediateItem) -> Promise<Any> {
        let type = checkSecondaryType(intermediateItem)
        return Promise { seal in
            loadGeneralURLItem(intermediateItem: intermediateItem, type: type, seal: seal)
        }
    }
    
    private func loadGeneralURLItem(intermediateItem: IntermediateItem, type: String, seal: Resolver<Any>) {
        intermediateItem.itemProvider.loadItem(
            forTypeIdentifier: type,
            options: nil,
            completionHandler: { item, error in
                if let error {
                    seal.reject(error)
                }
                if let urlItem = item as? URL, urlItem.scheme == "file" {
                    self.loadURLItem(urlItem: urlItem, type: type, seal: seal)
                }
                if self.isDataLoadable(type: type), let dataItem = item as? Data {
                    self.loadDataItem(dataItem: dataItem, type: type, seal: seal)
                }
                if UTIConverter.type(type, conformsTo: kUTTypeImage as String), let imageItem = item as? UIImage {
                    self.loadImageItem(imageItem: imageItem, seal: seal)
                }
                if let item {
                    seal.fulfill(item)
                }
                else {
                    DDLogError("Item could not be loaded.")
                    seal.reject(ItemLoaderError.UnknownType)
                }
            }
        )
    }
    
    private func isDataLoadable(type: String) -> Bool {
        UTIConverter.type(type, conformsTo: kUTTypeData as String) ||
            UTIConverter.isPassMimeType(UTIConverter.mimeType(fromUTI: type))
    }
    
    private func loadURLItem(urlItem: URL, type: String, seal: Resolver<Any>) {
        let url = tmpDirURL
        let ext = UTIConverter.preferredFileExtension(forMimeType: UTIConverter.mimeType(fromUTI: type)) ?? urlItem
            .pathExtension
        fileOperationQueue.sync {
            let ogFilename = urlItem.deletingPathExtension().lastPathComponent
            let filename = FileUtility.shared.getUniqueFilename(from: ogFilename, directoryURL: url, pathExtension: ext)
            let fileURL = url.appendingPathComponent(filename).appendingPathExtension(ext)
            do {
                try FileManager.default.copyItem(at: urlItem, to: fileURL)
            }
            catch {
                seal.reject(error)
                return
            }
            
            seal.fulfill(fileURL)
        }
    }
    
    private func loadDataItem(dataItem: Data, type: String, seal: Resolver<Any>) {
        let url = tmpDirURL
        fileOperationQueue.sync {
            guard let ext = UTIConverter.preferredFileExtension(forMimeType: UTIConverter.mimeType(fromUTI: type))
            else {
                seal.reject(ItemLoaderError.UnknownType)
                return
            }
            let filename = FileUtility.shared.getTemporarySendableFileName(
                base: "file",
                directoryURL: url,
                pathExtension: ext
            )
            let fileURL = url.appendingPathComponent(filename).appendingPathExtension(ext)
            do {
                try dataItem.write(to: fileURL)
            }
            catch {
                seal.reject(error)
            }
            seal.fulfill(fileURL)
        }
    }
    
    private func loadImageItem(imageItem: UIImage, seal: Resolver<Any>) {
        let isSticker = ImageURLSenderItemCreator.isPNGSticker(image: imageItem, uti: UTType.png.identifier)
        let imageData: Data? =
            if isSticker {
                MediaConverter.pngRepresentation(for: imageItem)
            }
            else {
                MediaConverter.jpegRepresentation(
                    for: imageItem,
                    withQuality: ImageURLSenderItemCreator().imageCompressionQuality()
                )
            }
        guard let dataItem = imageData else {
            let errorDescription = "Could not create jpeg representation of image item"
            DDLogError(errorDescription)
            let errorTemp = NSError(domain: errorDescription, code: 0, userInfo: nil)
            seal.reject(errorTemp)
            return
        }
        
        let url = tmpDirURL
        fileOperationQueue.sync {
            let jpegExt = UTIConverter
                .preferredFileExtension(forMimeType: UTIConverter.mimeType(fromUTI: UTType.jpeg.identifier))!
            let pngExt = UTIConverter
                .preferredFileExtension(forMimeType: UTIConverter.mimeType(fromUTI: UTType.png.identifier))!
            let ext = isSticker ? pngExt : jpegExt
            let filename = FileUtility.shared.getTemporarySendableFileName(
                base: "image",
                directoryURL: url,
                pathExtension: ext
            )
            let fileURL = url.appendingPathComponent(filename).appendingPathExtension(ext)
            do {
                try dataItem.write(to: fileURL)
            }
            catch {
                seal.reject(error)
            }
            seal.fulfill(fileURL)
        }
    }
    
    @objc public static func getBaseUTIType(_ itemProvider: NSItemProvider) -> String {
        let typeIdentifiers = NSMutableArray(array: itemProvider.registeredTypeIdentifiers)
        
        if typeIdentifiers.count >= 1 {
            return typeIdentifiers.lastObject as! String
        }
        return UTType.fileURL.identifier
    }
    
    @objc public static func getSecondUTIType(_ itemProvider: NSItemProvider, baseType: String) -> String? {
        let typeIdentifiers = NSMutableArray(array: itemProvider.registeredTypeIdentifiers)
        
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            typeIdentifiers.remove(UTType.fileURL.identifier)
        }
        if typeIdentifiers.count >= 1 {
            return (typeIdentifiers.first(where: { element in
                (element as? String)?.contains("public.") ?? false && (element as? String) != baseType
            }) as? String) ?? typeIdentifiers.firstObject as? String
        }
        return UTType.fileURL.identifier
    }
}
