import Foundation

public enum PhotosPickerError: Error {
    case fileNotFound
    case fileTooLargeForShareExtension
    case fileTooLargeForSending
    case unknown
}
