//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import DSWaveformImage
import DSWaveformImageViews
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

protocol VoiceMessageRecorderViewDelegate: AnyObject {
    func willDismissRecorder()
}

struct VoiceMessageRecorderView: View {
    @ObservedObject var model: Model
    @Environment(\.sizeCategory) var sizeCategory
    @State var renderer = LinearWaveformRenderer()
    
    private weak var delegate: VoiceMessageRecorderViewDelegate?
    @AccessibilityFocusState(for: .voiceOver) private var isStopFocused: Bool
    
    var container: some View {
        HStack(
            spacing: ChatViewConfiguration.ChatBar.textInputButtonSpacing
        ) {
            discardButton
            waveFormContainer
            sendButton
        }
        .padding(.horizontal, ChatViewConfiguration.ChatBar.textInputButtonSpacing)
        .frame(height: minBarHeight)
    }
    
    var body: some View {
        container
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isStopFocused = true
                }
            }
            .accessibilityAction(.magicTap) {
                model.voiceMessageManager.handleMagicTap()
            }
    }
    
    private var shouldShowFullWaveform: Bool {
        !model.recordingState.isRecording
    }
    
    private var waveFormContainer: some View {
        HStack {
            Spacer(minLength: leftInset)
            Group {
                waveform
                    .horizontalFadeOut(fadeLength: 30)
                durationView
            }.applyIf(sizeCategory.isAccessibilityCategory) { _ in
                HStack {
                    durationView
                    Spacer()
                }
            }
            Spacer(minLength: minBarHeight)
        }
        .animation(.easeIn.speed(2.0), value: leftInset)
        .foregroundColor(.gray)
        .overlay(alignment: .trailing) {
            if model.recordingState.isRecording {
                stopButton
                    .disabled(model.recordingState == .recordingStarting)
            }

            if model.recordingState.isStopped {
                addButton
                    .disabled(model.recordingState == .recordingStopping)
            }
        }
        .overlay(alignment: .leading) {
            if model.recordingState.isStopped {
                playPauseButton
            }
        }
        .background {
            RoundedRectangle(cornerRadius: ChatViewConfiguration.ChatTextView.cornerRadius)
                .fill(Colors.chatBarInput.color)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: ChatViewConfiguration.ChatTextView.cornerRadius
                    )
                    .stroke(Colors.hairLine.color, lineWidth: 0.5)
                )
        }
    }
    
    private var waveform: some View {
        WaveformLiveCanvas(
            samples: model.samples,
            configuration: model.configuration,
            renderer: renderer,
            shouldDrawSilencePadding: model.shouldDrawSilence
        )
        .opacity(shouldShowFullWaveform ? 0.0 : 1.0)
        .animation(.easeInOut, value: shouldShowFullWaveform)
        .foregroundColor(.clear)
        .overlay {
            if shouldShowFullWaveform {
                ProgressViewWaveform()
                    .environmentObject(model)
                    .animation(.easeInOut, value: shouldShowFullWaveform)
            }
        }
        .background {
            GeometryReader { geometry in
                let modified = model.configuration.with(size: geometry.size)
                VStack { }.onAppear {
                    model.loadSamples(count: Int(modified.size.width * modified.scale))
                }
            }
        }
    }
    
    private var durationView: some View {
        Text(DateFormatter.timeFormatted(model.duration) ?? "00:00")
            .font(.subheadline)
            .monospacedDigit()
            .dynamicTypeSize(...DynamicTypeSize.accessibility4)
            .accessibilityLabel(ThreemaUtility.accessibilityString(atTime: model.duration, with: "duration"))
    }
    
    private var minBarHeight: CGFloat {
        if sizeCategory < .large {
            ChatViewConfiguration.ChatTextView.smallerContentSizeConfigurationCornerRadius * 2
        }
        else {
            ChatViewConfiguration.ChatTextView.cornerRadius * 2
        }
    }
    
    private var leftInset: CGFloat {
        model.recordingState.isStopped
            ? minBarHeight
            : ChatViewConfiguration.ChatBar.textInputButtonSpacing
    }
    
    private func willDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: DispatchWorkItem(block: {
            if model.recordingState.isRecording {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }))
        model.recordingState = .none
        model.willDismissView()
        delegate?.willDismissRecorder()
    }
    
    private func willSend() {
        model.send()
        delegate?.willDismissRecorder()
    }
}

// MARK: - Buttons

extension VoiceMessageRecorderView {
    private var stopButton: some View {
        buildButton(
            "stop.circle.fill",
            .tint,
            .tint.opacity(0.2),
            {
                model.stop()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
        .accessibilityLabel(#localize("stop"))
        .accessibilityFocused($isStopFocused)
    }
    
    private var playPauseButton: some View {
        buildButton(
            model.recordingState == .paused || model
                .recordingState == .stopped || model
                .recordingState == .recordingStopping ? "play.circle.fill" : "pause.circle.fill",
            .gray,
            .gray.opacity(0.2),
            {
                model.play()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
        .accessibilityLabel((
            model.recordingState == .paused || model
                .recordingState == .stopped || model.recordingState == .recordingStopping ? "play" : "pause"
        ).localized)
    }
    
    private var addButton: some View {
        buildButton(
            "plus",
            .tint,
            .tint,
            {
                model.record()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
        .scaleEffect(0.6)
        .accessibilityLabel(#localize("record_continue"))
    }
    
    private var sendButton: some View {
        Button {
            willSend()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .renderingMode(.template)
                .imageScale(.large)
                .font(
                    .system(
                        size: UIFontMetrics(
                            forTextStyle: .body
                        )
                        .scaledValue(
                            for: ChatViewConfiguration.ChatBar.sendButtonSize
                        ),
                        weight: .regular
                    )
                )
                .foregroundColor(model.recordingState == .recordingStopping ? .secondary : UIColor.primary.color)
        }
        .disabled(model.recordingState == .recordingStopping)
        .accessibilityLabel(#localize("send"))
    }
    
    private var discardButton: some View {
        Button(action: {
            willDismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .renderingMode(.template)
                .imageScale(.large)
                .font(
                    .system(
                        size: UIFontMetrics(
                            forTextStyle: .body
                        )
                        .scaledValue(
                            for: ChatViewConfiguration.ChatBar.plusButtonSize
                        ),
                        weight: .regular
                    )
                )
                .foregroundColor(.gray)
        }
        .accessibilityLabel(#localize("quit"))
    }
    
    private func buildButton(
        _ systemImageName: String,
        _ primary: some ShapeStyle,
        _ secondary: some ShapeStyle,
        _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(primary, secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(4)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - VoiceMessageRecorderViewController

typealias VoiceMessageRecorderViewController = UIHostingController<VoiceMessageRecorderView>

extension VoiceMessageRecorderView {
    static func make(
        to view: UIView,
        with delegate: VoiceMessageRecorderViewDelegate?,
        model: Model
    ) -> VoiceMessageRecorderViewController {
        let hostingController = UIHostingController(
            rootView: VoiceMessageRecorderView(
                model: model,
                delegate: delegate
            )
        )
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        
        return hostingController
    }
}

extension VoiceMessageRecorderViewController {
    func audioFileURL(shouldMove: Bool) async throws -> SessionState {
        try await rootView.model.voiceMessageManager.savedSession(shouldMove)
    }
    
    var recordingState: RecordingState {
        rootView.model.recordingState
    }
}
