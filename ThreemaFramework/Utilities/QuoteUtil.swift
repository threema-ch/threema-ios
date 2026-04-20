import Foundation

@objc public final class QuoteUtil: NSObject {
    
    // MARK: - Regex
    
    private static let quoteRegexV2: NSRegularExpression = try! NSRegularExpression(
        pattern: #"^> quote #[0-9a-f]{16}(\r?\n){2}"#,
        options: [.dotMatchesLineSeparators]
    )
    
    private static let lineQuotesRegexV2: NSRegularExpression = try! NSRegularExpression(
        pattern: #"^> quote #"#,
        options: [.anchorsMatchLines]
    )
    
    // MARK: - Parsing

    @objc public static func parseQuoteV2(from message: String?) -> QuoteParseV2Result? {
        guard let message else {
            return nil
        }
        
        let match = quoteRegexV2.firstMatch(
            in: message,
            range: NSRange(location: 0, length: message.utf16.count)
        )
        
        guard let match, match.numberOfRanges == 2 else {
            return nil
        }
        
        let matchRange = match.range(at: 0)
        guard matchRange.location == 0 else {
            return nil
        }
        
        let quoteString = message.substring(range: match.range(at: 0)).trimmingCharacters(in: .whitespacesAndNewlines)
        let remainingBody = message.substring(range: NSRange(
            location: matchRange.length,
            length: message.utf16.count - matchRange.length
        ))
        
        var messageID = quoteString
        messageID = lineQuotesRegexV2.stringByReplacingMatches(
            in: messageID,
            range: NSRange(location: 0, length: messageID.utf16.count),
            withTemplate: ""
        )
        
        guard let decoded = messageID.hexadecimal else {
            return nil
        }
        return QuoteParseV2Result(messageID: decoded, remainingBody: remainingBody)
    }

    // MARK: - Generate
    
    @objc public static func generateText(_ text: String, quotedID: Data) -> String {
        var quoteString = "> quote #"
        quoteString += quotedID.hexString
        quoteString += "\n\n"
        quoteString += text
        return quoteString
    }
}

// MARK: - Helpers

@objc public final class QuoteParseV2Result: NSObject {
    @objc public let messageID: Data
    @objc public let remainingBody: String

    @objc init(messageID: Data, remainingBody: String) {
        self.messageID = messageID
        self.remainingBody = remainingBody
        super.init()
    }
}

extension String {
    fileprivate func substring(range: NSRange) -> String {
        guard let range = Range(range, in: self) else {
            return ""
        }
        return String(self[range])
    }
}
