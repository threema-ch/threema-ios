import CocoaLumberjackSwift
import FileUtility
import Foundation

@objc public final class URLSenderItemCreator: NSObject {
    
    public static func getSenderItem(for url: URL, maxSize: ImageSenderItemSize?) -> URLSenderItem? {
        if !URLSenderItemCreator.validate(url: url) {
            return nil
        }
        let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier

        var item: URLSenderItem?
        
        if UTIConverter.conforms(toMovieType: uti) {
            let creator = VideoURLSenderItemCreator()
            item = creator.senderItem(from: url)
        }
        else if UTIConverter.conforms(toImageType: uti) {
            let creator =
                if let maxSize {
                    ImageURLSenderItemCreator(with: maxSize)
                }
                else {
                    ImageURLSenderItemCreator()
                }
            item = creator.senderItem(from: url)
        }
        else {
            item = URLSenderItem(url: url, type: uti, renderType: NSNumber(value: 0), sendAsFile: true)
        }
        return item
    }
    
    /// Will return a sender item for the file at url. The file will be transcoded or scaled and its metadata will be
    /// removed
    /// if it conforms to isMovieMimeType or isImageMimeType.
    /// - Parameter url: The url at which the file is stored
    /// - Returns: An url sender item if one can be created
    @objc public static func getSenderItem(for url: URL) -> URLSenderItem? {
        URLSenderItemCreator.getSenderItem(for: url, maxSize: nil)
    }
    
    private static func validate(url: URL) -> Bool {
        guard url.scheme == "file" else {
            return false
        }
        guard FileUtility.shared.fileExists(at: url) == true else {
            return false
        }
        return true
    }
}
