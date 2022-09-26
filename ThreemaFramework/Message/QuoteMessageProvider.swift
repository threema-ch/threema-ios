//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

/// Provides the quoted message
public protocol QuoteMessageProvider: BaseMessage {
    /// `QuotedMessage` if it exists, `nil` otherwise
    var quoteMessage: QuoteMessage? { get }
}

/// A quoted message
public protocol QuoteMessage {
    /// Represents type of quote message and contains info of it.
    var quoteMessageType: QuoteMessageType { get }
    /// Readable name of the author of the quoted message.
    var quotedSender: String { get }
}

/// Contains the different types of quoted messages, used in new chat view cells for quotes
public enum QuoteMessageType {
    // TODO: Add file message types
    
    /// A quoted text message
    case text(String)
    /// A quoted location. First a string for the location, second an SF Symbols name.
    case location(String, String)
    /// A quoted ballot. First a string for the name of the ballot, second an SF Symbols name.
    case ballot(String, String)
    /// An error message for quotes. First a string for the error message, second an SF Symbols name.
    case error(String, String)
}
