//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class VideoImageCell: ScreenWidthSizedCell, UIGestureRecognizerDelegate {
    @IBOutlet var videoBackgroundView: UIView!
    @IBOutlet var loadingView: UIView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var loadingVideoText: UILabel!
    @IBOutlet var playButton: UIImageView!
    
    var indexPath: IndexPath?
    var player: AVPlayer?
    var isPlaying = false
    var currentVideo: AVPlayerLayer?
    
    @objc func playerDidFinishPlaying(note: NSNotification) {
        player?.seek(to: .zero)
        playButton.isHidden = false
        isPlaying = false
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
        showLoadingScreen()
        if let video = currentVideo {
            video.removeFromSuperlayer()
        }
    }
    
    func addAccessibilityLabels() {
        videoBackgroundView.accessibilityLabel = BundleUtil.localizedString(forKey: "video")
        loadingView.accessibilityLabel = BundleUtil.localizedString(forKey: "loading_video")
    }
    
    func videoLoaded() {
        playButton.isHidden = false
        loadingView.isHidden = true
    }
    
    func setColors() {
        backgroundView?.backgroundColor = .clear
        backgroundColor = .clear
        videoBackgroundView.backgroundColor = .clear
        loadingView.backgroundColor = .clear
        playButton.tintColor = .white
        playButton.image = playButton.image?.draw(withTintColor: .white)
    }
    
    func showLoadingScreen() {
        setColors()
        
        videoBackgroundView.isHidden = true
        playButton.isHidden = true
        loadingView.isHidden = false
        activityIndicator.isHidden = false
        loadingVideoText.isHidden = false
        
        activityIndicator.startAnimating()
        
        loadingVideoText.text = BundleUtil.localizedString(forKey: "loading_video")
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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        }
        catch {
            DDLogError("Could not create AudioSession for .moviePlayback")
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if playerItem.status != .readyToPlay, playerItem.status != .failed {
                return
            }
            DispatchQueue.main.async {
                self.videoBackgroundView.isHidden = false

                let view = UIView(frame: playerLayer.videoRect)
                view.backgroundColor = .clear
                
                self.videoBackgroundView.addSubview(view)
                self.videoBackgroundView.bringSubviewToFront(view)
                
                let tapGR = UITapGestureRecognizer(target: self, action: #selector(VideoImageCell.handleTap(_:)))
                tapGR.delegate = self
                tapGR.numberOfTapsRequired = 1
                view.addGestureRecognizer(tapGR)
                
                self.videoLoaded()
                timer.invalidate()
            }
        }
        timer.tolerance = 0.1
    }
    
    func togglePlaying() {
        if isPlaying {
            pauseVideo()
        }
        else {
            isPlaying = true
            playButton.isHidden = true
            player?.play()
        }
    }
    
    @objc func pauseVideo() {
        DispatchQueue.main.async {
            self.player?.pause()
            self.isPlaying = false
            self.playButton.isHidden = false
        }
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
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
        loadingVideoText.text = BundleUtil.localizedString(forKey: "loading_video_failed")
        loadingVideoText.isHidden = false
    }
}
