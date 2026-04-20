import Foundation

extension AudioDataEntity: ExternalStorageInfo {
    public func getFilename() -> String? {
        // Do NOT use `AudioDataEntity.data` property directly, as it has been casted from NSData to Data and the
        // external file information has been lost
        guard let data = primitiveValue(forKey: "data") as? NSData else {
            return nil
        }
        return ExternalStorage.getFilename(data: data)
    }
}
