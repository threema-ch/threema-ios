//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

/// This parses any type of URL and returns the `URLType` or throws an error if the URL cannot be parsed
///
/// This is a **WORK IN PROGRESS** and is only used for `deviceGroupJoinRequestOffer` right now.
public enum URLParser {
    
    // MARK: - Types
    
    /// Type of parsed URL
    public enum URLType: Equatable {
        case deviceGroupJoinRequestOffer(urlSafeBase64: String)
        case file(url: URL)
        case url(url: URL)
        case unsafeURL(url: URL)
    }
    
    public enum Error: Swift.Error {
        case invalidAppSchemeURL
        case unableToParseURL
        case unknownURLScheme
    }
    
    // MARK: Public interface
    
    /// Parse the passed URL
    /// - Parameter url: URL to parse
    /// - Returns: Parsed URL as `URLType`
    /// - Throws: `URLParser.Error` if parsing fails
    public static func parse(url: URL) throws -> URLType {
        guard let scheme = url.scheme else {
            throw Error.unableToParseURL
        }
        
        switch scheme {
        case let threemaScheme where threemaScheme.hasPrefix("threema"):
            return try parse(threemaURL: url)
        case "http", "https":
            return parse(webURL: url)
        case "file":
            return .file(url: url)
        default:
            throw Error.unknownURLScheme
        }
    }
    
    // MARK: - Helper functions
    
    private static func parse(threemaURL: URL) throws -> URLType {
        guard threemaURL.scheme?.hasPrefix("threema") ?? false else {
            throw Error.unableToParseURL
        }
        
        guard let host = threemaURL.host else {
            throw Error.invalidAppSchemeURL
        }
        
        switch host {
        case "device-group":
            return try parse(threemaDeviceGroupURL: threemaURL)
        default:
            // TODO: Implement more
            throw Error.unknownURLScheme
        }
    }
    
    private static func parse(threemaDeviceGroupURL: URL) throws -> URLType {
        switch threemaDeviceGroupURL.path {
        case "/join":
            if let fragment = threemaDeviceGroupURL.fragment {
                let cleanedUpFragment: String
                // From the protocol documentation: All URLs should have a trailing slash.
                // We still support non trailing slashes...
                if fragment.last == "/" {
                    cleanedUpFragment = String(fragment.dropLast(1))
                }
                else {
                    cleanedUpFragment = fragment
                }
                
                return .deviceGroupJoinRequestOffer(urlSafeBase64: cleanedUpFragment)
            }
            
            throw Error.invalidAppSchemeURL
        default:
            throw Error.invalidAppSchemeURL
        }
    }
    
    private static func parse(webURL: URL) -> URLType {
        // TODO: Parse threema.ch & threema.id urls
        
        if webURL.isIDNASafe {
            return .url(url: webURL)
        }
        else {
            return .unsafeURL(url: webURL)
        }
    }
}
