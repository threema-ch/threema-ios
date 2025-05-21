//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import ThreemaMacros

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
        player?.pause()
        showLoadingScreen()
        if let video = currentVideo {
            video.removeFromSuperlayer()
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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        }
        catch {
            DDLogError("Could not create AudioSession for .moviePlayback")
        }
        
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
            self.player?.play()
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
        loadingVideoText.text = #localize("loading_video_failed")
        loadingVideoText.isHidden = false
    }
}
