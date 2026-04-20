// swiftformat:disable acronyms

import Foundation

public struct OnPremConfigBlob: Decodable, Sendable {
    // Note: these are Strings instead of URLs so that they can include placeholders
    let uploadUrl: String
    let downloadUrl: String
    let doneUrl: String
}
