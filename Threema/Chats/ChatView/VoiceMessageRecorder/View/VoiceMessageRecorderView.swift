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
    @Environment(\.sizeCategory) var sizeCategory
    @ObservedObject var model: VoiceMessageRecorderViewModel
    @State var renderer = LinearWaveformRenderer()
    
    @AccessibilityFocusState(for: .voiceOver) private var isStopFocused: Bool
    
    // MARK: - Private properties
    
    private weak var delegate: VoiceMessageRecorderViewDelegate?
    
    private var shouldShowFullWaveform: Bool {
        !(model.recordingState == .recording)
    }
    
    private var minBarHeight: CGFloat {
        if sizeCategory < .large {
            if #available(iOS 26.0, *) {
                // Due to an unknown reason, we need twice the radius on iPads (regardless of compact or regular size
                // class)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    ChatTextViewConfiguration.smallerContentSizeConfigurationCornerRadius * 4
                }
                else {
                    ChatTextViewConfiguration.smallerContentSizeConfigurationCornerRadius * 2
                }
            }
            else {
                ChatTextViewConfiguration.smallerContentSizeConfigurationCornerRadius * 2
            }
        }
        else {
            if #available(iOS 26.0, *) {
                // Due to an unknown reason, we need twice the radius on iPads (regardless of compact or regular size
                // class)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    ChatTextViewConfiguration.cornerRadius * 4
                }
                else {
                    ChatTextViewConfiguration.cornerRadius * 2
                }
            }
            else {
                ChatTextViewConfiguration.cornerRadius * 2
            }
        }
    }
    
    private var leftInset: CGFloat {
        model.recordingState.recordingStopped
            ? minBarHeight
            : ChatBarConfiguration.textInputButtonSpacing
    }
    
    // MARK: - Subviews
    
    private var container: some View {
        let spacing =
            if #available(iOS 26, *) {
                ChatBarConfiguration.textInputButtonSpacing / 2
            }
            else {
                ChatBarConfiguration.textInputButtonSpacing
            }
       
        return HStack(
            spacing: spacing
        ) {
            discardButton
            waveFormContainer
            sendButton
        }
        .apply { view in
            if #available(iOS 26.0, *) {
                view
            }
            else {
                view
                    .padding(.horizontal, ChatBarConfiguration.textInputButtonSpacing)
            }
        }
        .frame(minHeight: minBarHeight)
    }
    
    // MARK: WaveForm
    
    private var waveFormContainer: some View {
        HStack {
            Spacer(minLength: leftInset)
            Group {
                waveform
                    .horizontalFadeOut(fadeLength: model.recordingState == .recording ? 5 : 0)
                    .padding(.vertical, 5)
                durationView
            }
            .applyIf(sizeCategory.isAccessibilityCategory) { _ in
                HStack {
                    durationView
                    Spacer()
                }
            }
            Spacer(minLength: minBarHeight)
        }
        .foregroundColor(.gray)
        .overlay(alignment: .trailing) {
            if model.recordingState == .recording {
                stopButton
            }

            if model.recordingState.recordingStopped {
                addButton
            }
        }
        .overlay(alignment: .leading) {
            if model.recordingState.recordingStopped {
                playPauseButton
            }
        }
        .apply { view in
            if #available(iOS 26.0, *) {
                view
                    .glassEffect()
                    .clipShape(RoundedRectangle(cornerRadius: ChatTextViewConfiguration.cornerRadius))
            }
            else {
                view
                    .background {
                        RoundedRectangle(cornerRadius: ChatTextViewConfiguration.cornerRadius)
                            .fill(Colors.chatBarInput.color)
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: ChatTextViewConfiguration.cornerRadius
                                )
                                .stroke(Colors.hairLine.color, lineWidth: 0.5)
                            )
                    }
            }
        }
    }
    
    private var waveform: some View {
        WaveformLiveCanvas(
            samples: model.samples,
            configuration: model.waveFormConfiguration,
            renderer: renderer
        )
        .opacity(shouldShowFullWaveform ? 0.0 : 1.0)
        .animation(.none, value: shouldShowFullWaveform)
        .foregroundColor(.clear)
        .overlay {
            if shouldShowFullWaveform {
                ProgressViewWaveform()
                    .environmentObject(model)
                    .animation(.none, value: shouldShowFullWaveform)
            }
        }
        .background {
            GeometryReader { geometry in
                let modified = model.waveFormConfiguration.with(size: geometry.size)
                VStack { }.onAppear {
                    model.loadSamples(count: Int(modified.size.width * modified.scale))
                }
            }
        }
    }
    
    // MARK: Duration
    
    private var durationView: some View {
        Text(DateFormatter.timeFormatted(model.duration) ?? "00:00")
            .font(.subheadline)
            .monospacedDigit()
            .dynamicTypeSize(...DynamicTypeSize.accessibility4)
            .accessibilityLabel(ThreemaUtility.accessibilityString(atTime: model.duration, with: #localize("duration")))
    }
    
    // MARK: Buttons
    
    private var stopButton: some View {
        buildButton(
            "stop.circle.fill",
            .tint,
            .tint.opacity(0.2)
        ) {
            Task {
                await model.stopRecording()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }

        .accessibilityLabel(#localize("stop"))
        .accessibilityFocused($isStopFocused)
    }
    
    private var playPauseButton: some View {
        buildButton(
            model.recordingState == .paused || model
                .recordingState == .stopped ? "play.circle.fill" : "pause.circle.fill",
            .gray,
            .gray.opacity(0.2)
        ) {
            if model.recordingState == .playing {
                model.pause()
            }
            else {
                model.play()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        .accessibilityLabel(#localize(
            model.recordingState == .paused || model
                .recordingState == .stopped ? "play" : "pause"
        ))
    }
    
    private var addButton: some View {
        buildButton(
            "plus",
            .tint,
            .tint
        ) {
            Task {
                await model.continueRecording()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .scaleEffect(0.6)
        .accessibilityLabel(#localize("record_continue"))
    }
    
    private var sendButton: some View {
        if #available(iOS 26.0, *) {
            // swiftformat:disable:next all
            return Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .renderingMode(.template)
                    .foregroundStyle(Color(.labelInverted))
                    .font(
                        .system(
                            size: UIFontMetrics(
                                forTextStyle: .body
                            )
                            .scaledValue(
                                for: ChatBarConfiguration.defaultSize
                            ),
                            weight: .semibold
                        )
                    )
                    .padding(3)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel(#localize("send"))
        }
        else {
            // swiftformat:disable:next all
            return Button {
                send()
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
                                for: ChatBarConfiguration.sendButtonSize
                            ),
                            weight: .regular
                        )
                    )
                    .foregroundColor(.accentColor)
            }
            .accessibilityLabel(#localize("send"))
        }
    }
    
    private var discardButton: some View {
        if #available(iOS 26.0, *) {
            // swiftformat:disable:next all
            return Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .renderingMode(.template)
                    .font(
                        .system(
                            size: UIFontMetrics(
                                forTextStyle: .body
                            )
                            .scaledValue(
                                for: ChatBarConfiguration.defaultSize
                            ),
                            weight: .regular
                        )
                    ).padding(4)
            }
            .clipShape(Circle())
            .buttonStyle(.glass)
            .accessibilityLabel(#localize("quit"))
        }
        else {
            // swiftformat:disable:next all
            return Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .renderingMode(.template)
                    .imageScale(.large)
                    .font(
                        .system(
                            size: UIFontMetrics(
                                forTextStyle: .body
                            )
                            .scaledValue(
                                for: ChatBarConfiguration.plusButtonSize
                            ),
                            weight: .regular
                        )
                    )
                    .foregroundColor(.gray)
            }
            .accessibilityLabel(#localize("quit"))
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        container
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isStopFocused = true
                }
            }
            .accessibilityAction(.magicTap) {
                Task {
                    await model.handleMagicTap()
                }
            }
    }
    
    // MARK: - Private functions
    
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
    
    private func dismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: DispatchWorkItem(block: {
            if model.recordingState == .recording {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }))
        model.recordingState = .ready
        model.willDismissView()
        delegate?.willDismissRecorder()
    }
    
    private func send() {
        model.sendRecording {
            model.willDismissView()
            delegate?.willDismissRecorder()
        }
    }
}

// MARK: - VoiceMessageRecorderViewController

typealias VoiceMessageRecorderViewController = UIHostingController<VoiceMessageRecorderView>

extension VoiceMessageRecorderView {
    static func make(
        to view: UIView,
        with delegate: VoiceMessageRecorderViewDelegate?,
        model: VoiceMessageRecorderViewModel
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
    func saveVoiceMessageRecordingAsDraft() {
        rootView.model.saveVoiceMessageRecordingAsDraft()
    }
    
    var recordingState: RecordingState {
        rootView.model.recordingState
    }
}
