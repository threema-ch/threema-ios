import AudioSessionManager
import CocoaLumberjackSwift
import ThreemaMacros

final class VideoImageCell: ScreenWidthSizedCell, UIGestureRecognizerDelegate {
    @IBOutlet var videoBackgroundView: UIView!
    @IBOutlet var loadingView: UIView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var loadingVideoText: UILabel!
    @IBOutlet var playButton: UIImageView!
    
    var indexPath: IndexPath?
    var player: AVPlayer?
    var isPlaying = false
    var currentVideo: AVPlayerLayer?

    /// Held while this cell's video is playing.
    private var audioSessionClaim: AudioSessionClaim?

    @objc private func playerDidFinishPlaying(note: NSNotification) {
        player?.seek(to: .zero)
        playButton.isHidden = false
        isPlaying = false
        releaseAudioSessionClaim()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseVideo),
            name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo),
            object: nil
        )
    }
    
    override func prepareForReuse() {
        player?.pause()
        showLoadingScreen()
        if let video = currentVideo {
            video.removeFromSuperlayer()
        }
        releaseAudioSessionClaim()
    }

    deinit {
        guard let claim = audioSessionClaim else {
            return
        }

        // Copied into a local: the `Task` outlives this cell.
        let manager = audioSessionManager
        Task {
            await manager.release(claim)
        }
    }

    // MARK: - Audio session claim

    // Used like this, because we cannot inject the businesInjector
    private var audioSessionManager: any AudioSessionManagerProtocol {
        BusinessInjector.ui.audioSessionManager
    }

    private func acquireAudioSessionClaim() {
        guard audioSessionClaim == nil else {
            return
        }

        Task { @MainActor [weak self] in
            let claim = try? await self?.audioSessionManager.acquire(.mediaPlayback)

            guard let self, let claim else {
                return
            }

            // Playback may already have stopped during the acquire.
            guard isPlaying else {
                await audioSessionManager.release(claim)
                return
            }

            audioSessionClaim = claim
        }
    }

    private func releaseAudioSessionClaim() {
        guard let claim = audioSessionClaim else {
            return
        }
        audioSessionClaim = nil

        let manager = audioSessionManager
        Task {
            await manager.release(claim)
        }
    }
    
    func addAccessibilityLabels() {
        videoBackgroundView.accessibilityLabel = #localize("video")
        loadingView.accessibilityLabel = #localize("loading_video")
    }
    
    func videoLoaded() {
        playButton.isHidden = false
        playButton.image = UIImage(systemName: "play.circle.fill")
        loadingView.isHidden = true
    }
    
    func setColors() {
        backgroundView?.backgroundColor = .clear
        backgroundColor = .clear
        videoBackgroundView.backgroundColor = .clear
        loadingView.backgroundColor = .clear
        playButton.tintColor = .white
        playButton.image = playButton.image?.withTintColor(.white)
    }
    
    func showLoadingScreen() {
        setColors()
        
        videoBackgroundView.isHidden = true
        playButton.isHidden = true
        loadingView.isHidden = false
        activityIndicator.isHidden = false
        loadingVideoText.isHidden = false
        
        activityIndicator.startAnimating()
        
        loadingVideoText.text = #localize("loading_video")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        currentVideo?.frame = bounds
        videoBackgroundView.layer.sublayers?.first?.frame = bounds
    }
    
    func updateVideoWithAsset(asset: AVAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.actionAtItemEnd = .pause
        
        let playerLayer = AVPlayerLayer()
        playerLayer.player = player
        playerLayer.frame = videoBackgroundView.frame
        playerLayer.videoGravity = .resizeAspect
        playerLayer.needsDisplayOnBoundsChange = true
        playerLayer.backgroundColor = UIColor.clear.cgColor
        
        videoBackgroundView.layer.addSublayer(playerLayer)
        currentVideo = playerLayer

        // Clean up previously added views and gesture recognizers
        for subview in videoBackgroundView.subviews {
            subview.removeFromSuperview()
        }
        gestureRecognizers?.removeAll()
        
        _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if playerItem.status != .readyToPlay, playerItem.status != .failed {
                return
            }
            timer.invalidate()
            
            DispatchQueue.main.async {
                self.videoBackgroundView.isHidden = false

                let view = UIView(frame: playerLayer.videoRect)
                view.backgroundColor = .clear
                
                self.videoBackgroundView.addSubview(view)
                self.videoBackgroundView.bringSubviewToFront(view)
                
                let tapGR = UITapGestureRecognizer(target: self, action: #selector(VideoImageCell.handleTap(_:)))
                tapGR.delegate = self
                view.addGestureRecognizer(tapGR)
                
                self.videoLoaded()
            }
        }
    }
    
    func togglePlaying() {
        if isPlaying {
            pauseVideo()
        }
        else {
            playVideo()
        }
    }
    
    func playVideo() {
        DispatchQueue.main.async {
            self.isPlaying = true
            self.playButton.isHidden = true
            self.acquireAudioSessionClaim()
            self.player?.play()
        }
    }
    
    @objc private func pauseVideo() {
        DispatchQueue.main.async {
            self.player?.pause()
            self.isPlaying = false
            self.playButton.isHidden = false
            self.releaseAudioSessionClaim()
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: nil
            )
            self.togglePlaying()
        }
    }
    
    func handleError() {
        loadingVideoText.text = #localize("loading_video_failed")
        loadingVideoText.isHidden = false
    }
}
