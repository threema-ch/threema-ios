//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import SwiftUI

struct AudioErrorDebugView: View {
    var body: some View {
        VStack {
            List {
                ForEach(VoiceMessageError.allCases) { error in
                    Button(action: {
                        presentError(error)
                    }) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(error)")
                                    .bold()
                                Text(error.localizedDescription)
                                Spacer()
                            }
                            
                            Text(error.failureReason ?? "-")
                                .font(.footnote)
                        }
                    }
                }
            }.listStyle(PlainListStyle())
        }
    }

    func presentError(_ error: VoiceMessageError) {
        error.showAlert()
    }
}

// MARK: - VoiceMessageError + CaseIterable, Identifiable

extension VoiceMessageError: CaseIterable, Identifiable {
    var id: String {
        switch self {
        case .audioSessionFailure:
            "audioSessionFailure"
        case .couldNotActivateCategory:
            "couldNotActivateCategory"
        case .callStateNotIdle:
            "callStateNotIdle"
        case .exportFailed:
            "exportFailed"
        case .audioFileMissing:
            "audioFileMissing"
        case .playbackFailure:
            "playbackFailure"
        case .noRecordPermission:
            "noRecordPermission"
        case .recordingCancelled:
            "recordingCancelled"
        case .assetNotFound:
            "assetNotFound"
        case .couldNotSave:
            "couldNotSave"
        case .recorderInitFailure:
            "recorderInitFailure"
        case .error:
            "error"
        case .fileOperationFailed:
            "fileOperationFailed"
        }
    }
    
    public static var allCases: [VoiceMessageError] {
        [
            .audioSessionFailure,
            .couldNotActivateCategory,
            .callStateNotIdle,
            .exportFailed,
            .audioFileMissing,
            .playbackFailure,
            .noRecordPermission,
            .recordingCancelled,
            .assetNotFound,
            .couldNotSave,
            .recorderInitFailure,
            .error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "A generic error occurred."])),
            .fileOperationFailed,
        ]
    }
}
