//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

extension AudioMessageEntity: VoiceMessage {
    
    override public var showRetryAndCancelButton: Bool {
        switch blobDisplayState {
        case .pending, .sendingError, .uploading:
            return true
        default:
            return false
        }
    }
    
    public var consumed: Date? {
        Date(timeIntervalSince1970: 0)
    }
    
    // MARK: - FileMessageProvider
    
    public var fileMessageType: FileMessageType {
        .voice(self)
    }
    
    // MARK: - ThumbnailDisplayMessage

    public var dataBlobFileSize: Measurement<UnitInformationStorage> {
        if let audioSize = audioSize?.doubleValue {
            return .init(value: audioSize, unit: .bytes)
        }
        else {
            assertionFailure("No audio file size available")
            return .init(value: 0, unit: .bytes)
        }
    }
    
    public var caption: String? {
        nil
    }
    
    public var durationTimeInterval: TimeInterval? {
        duration.doubleValue
    }
    
    public func temporaryBlobDataURL() -> URL? {
        guard let audio,
              let audioData = audio.data else {
            return nil
        }
        
        let filename = "v1-audioMessage-\(UUID().uuidString)"
        let url = FileUtility.shared.appTemporaryDirectory.appendingPathComponent(
            "\(filename).\(MEDIA_EXTENSION_AUDIO)"
        )
        
        do {
            try audioData.write(to: url)
        }
        catch {
            DDLogWarn("Writing audio blob data to temporary file failed: \(error)")
            return nil
        }
        
        return url
    }
}
