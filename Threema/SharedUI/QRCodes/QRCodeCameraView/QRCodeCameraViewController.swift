@preconcurrency
import AVFoundation

import AudioSessionManager
import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

final class QRCodeCameraViewController: UIViewController {

    // MARK: - Public properties

    var onCompletion: ((String?) -> Void)?

    // MARK: - Private properties

    private let audioSessionManager: (any AudioSessionManagerProtocol)?
    private let systemFeedbackManager: any SystemFeedbackManagerProtocol
    private let systemPermissionsManager: any SystemPermissionsManagerProtocol

    private var captureSession: AVCaptureSession?
    private var isRunning = false
    private var previewLayer = AVCaptureVideoPreviewLayer()
    private var previewView = UIView()
    private var initialPinchZoom: CGFloat = 1.0
    private var videoDevice: AVCaptureDevice?

    /// The scanner's claim, held only while the capture session runs.
    private var audioSessionClaim: AudioSessionClaim?

    // MARK: - Lifecycle

    init(
        audioSessionManager: (any AudioSessionManagerProtocol)?,
        systemFeedbackManager: any SystemFeedbackManagerProtocol,
        systemPermissionsManager: any SystemPermissionsManagerProtocol
    ) {
        self.audioSessionManager = audioSessionManager
        self.systemFeedbackManager = systemFeedbackManager
        self.systemPermissionsManager = systemPermissionsManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not available")
    }

    // MARK: - Override super class

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupObservers()
        setupPinchGesture()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateViews()
        resumeRunning()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            await handlePermissionsAndStartIfGranted()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRunning()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        let targetTransform = coordinator.targetTransform
        let inverseTransform = CGAffineTransformInvert(targetTransform)
        coordinator.animate { [weak self] _ in
            guard let self else {
                return
            }
            previewView.transform = CGAffineTransformConcat(previewView.transform, inverseTransform)
            previewView.frame = view.bounds
            previewLayer.frame = previewView.bounds
        }
    }

    // MARK: - Public methods

    func resumeRunning() {
        removeCornersPathLayers()
        guard !isRunning, let captureSession else {
            return
        }
        Task.detached {
            captureSession.startRunning()
        }
        isRunning = true
        acquireAudioSessionClaim()
    }

    func stopRunning() {
        guard isRunning else {
            return
        }
        captureSession?.stopRunning()
        releaseAudioSessionClaim()
        isRunning = false
    }

    // MARK: - Audio session claim

    private func acquireAudioSessionClaim() {
        // `nil` during onboarding, which has no `BusinessInjector` to take a manager from
        guard audioSessionClaim == nil, let manager = audioSessionManager else {
            return
        }

        Task { [weak self] in
            guard let claim = try? await manager.acquire(.ambient) else {
                return
            }

            guard let self, isRunning else {
                await manager.release(claim)
                return
            }

            audioSessionClaim = claim
        }
    }

    private func releaseAudioSessionClaim() {
        guard let claim = audioSessionClaim, let manager = audioSessionManager else {
            return
        }
        audioSessionClaim = nil

        Task {
            await manager.release(claim)
        }
    }

    // MARK: - Private types

    private struct ScannedCode {
        let value: String?
        let bezierPath: UIBezierPath?
    }

    // MARK: - Helpers

    private func setupViews() {
        view.backgroundColor = .black
        view.addSubview(previewView)
    }

    private func updateViews() {
        previewView.frame = view.bounds
        previewLayer.frame = previewView.bounds
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private func updateCameraOrientation() {
        guard let connection = previewLayer.connection else {
            return
        }

        let orientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown

        let rotationAngle: CGFloat =
            switch orientation {
            case .portrait: 90.0
            case .portraitUpsideDown: 270.0
            case .landscapeLeft: 180.0
            case .landscapeRight: 0.0
            default: 90.0 // default Portrait for Unknown, FaceUp, FaceDown
            }
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
        else {
            let fallbackAngles: [CGFloat] = [0.0, 90.0, 180.0, 270.0]
            for angle in fallbackAngles {
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                    break
                }
            }
        }
    }

    private func handlePermissionsAndStartIfGranted() async {
        let granted = await systemPermissionsManager.hasVideoCapturePermission()
        if granted {
            setupCaptureSessionIfNeeded()
            updateCameraOrientation()
            resumeRunning()
        }
        else {
            showCameraAccessAlert()
        }
    }

    private func setInitialZoomFactor() {
        do {
            guard let videoDevice else {
                return
            }
            try videoDevice.lockForConfiguration()
            defer { videoDevice.unlockForConfiguration() }
            videoDevice.videoZoomFactor = 1.0
        }
        catch { /* no-op */ }
    }

    private func setupCaptureSessionIfNeeded() {
        guard captureSession == nil else {
            return
        }

        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        videoDevice = device

        setInitialZoomFactor()

        let session = AVCaptureSession()

        guard
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return
        }

        session.addInput(input)

        let queue = DispatchQueue(label: "ch.threema.app.qrmetadata.serialQueue")
        let output = AVCaptureMetadataOutput()

        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        captureSession = session

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = previewView.bounds
        previewView.layer.addSublayer(layer)
        previewLayer = layer

        // This needs to be done after the output has been added to the session
        output.metadataObjectTypes = [.qr, .microQR]
        output.setMetadataObjectsDelegate(self, queue: queue)
    }

    private func setupPinchGesture() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        previewView.addGestureRecognizer(pinch)
    }

    private func showCameraAccessAlert() {
        UIAlertTemplate.showOpenSettingsAlert(owner: self, noAccessAlertType: .camera)
    }

    private func getFirstCodeFromMetadata(_ metadataObjects: [AVMetadataObject]) -> ScannedCode? {
        let code: ScannedCode? = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap { object -> ScannedCode? in
                // Read the decoded payload from the original metadata object. `transformedMetadataObject(for:)`
                // converts the geometry into preview-layer coordinates, but with some capture sources (e.g. the
                // RocketSim simulator camera) the transformed object comes back without a `stringValue`.
                guard let value = object.stringValue else {
                    return nil
                }
                // The transformed object is only used to draw the highlight overlay in layer coordinates; fall
                // back to the original corners (which may be empty) so a missing highlight never drops the scan.
                let transformed = previewLayer.transformedMetadataObject(for: object) as? AVMetadataMachineReadableCodeObject
                let corners = transformed?.corners ?? object.corners
                return ScannedCode(value: value, bezierPath: bezierPath(for: corners))
            }
            .first
        return code
    }

    private func bezierPath(for corners: [CGPoint]) -> UIBezierPath? {
        guard let firstPoint = corners.first else {
            return nil
        }
        let bezierPath = UIBezierPath()
        bezierPath.move(to: firstPoint)
        for point in corners.dropFirst() {
            bezierPath.addLine(to: point)
        }
        bezierPath.close()
        return bezierPath
    }

    private func addCornersPathLayer(from code: ScannedCode) {
        guard let bezierPath = code.bezierPath else {
            return
        }
        let layer = CAShapeLayer()
        layer.path = bezierPath.cgPath
        layer.lineWidth = 2.0
        layer.strokeColor = UIColor.blue.cgColor
        layer.fillColor = UIColor.blue.withAlphaComponent(0.5).cgColor
        previewLayer.addSublayer(layer)
    }

    private func removeCornersPathLayers() {
        previewLayer.sublayers.map { layers in
            layers
                .filter { $0 is CAShapeLayer }
                .forEach { $0.removeFromSuperlayer() }
        }
    }

    // MARK: - ObjectiveC methods

    @objc private func willEnterForegroundNotification() {
        resumeRunning()
    }

    @objc private func didEnterBackgroundNotification() {
        stopRunning()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = videoDevice else {
            return
        }
        if gesture.state == .began {
            initialPinchZoom = device.videoZoomFactor
        }
        if gesture.state == .changed {
            let maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let newZoomFactor = min(max(1.0, device.videoZoomFactor * gesture.scale), maxZoomFactor)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoomFactor
                device.unlockForConfiguration()
            }
            catch { }
            gesture.scale = 1.0
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeCameraViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        stopRunning()
        guard let scannedCode = getFirstCodeFromMetadata(metadataObjects) else {
            Task { @MainActor [weak self] in
                self?.resumeRunning()
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            systemFeedbackManager.vibrate()
            removeCornersPathLayers()
            addCornersPathLayer(from: scannedCode)
            try await Task.sleep(seconds: 0.25)
            onCompletion?(scannedCode.value)
        }
    }
}
