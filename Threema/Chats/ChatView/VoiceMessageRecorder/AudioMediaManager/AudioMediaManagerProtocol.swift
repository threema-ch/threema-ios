import Foundation

protocol AudioMediaManagerProtocol: AnyObject {
    static func newRecordingAudioURL() -> URL
    static func concatenateRecordingsAndSave(combine urls: [URL], to audioFile: URL) async throws -> AVAsset
    static func moveToDocumentsDir(from url: URL) throws -> URL
    static func copy(source: URL, destination: URL) throws
    static func cleanupFile(_ url: URL)
}
