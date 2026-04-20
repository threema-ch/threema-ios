import Foundation

protocol ResourceLoaderProtocol {
    func loadContentAsString(_ fileName: String, fileExtension: String) -> String?
}
