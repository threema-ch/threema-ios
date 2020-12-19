//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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

class VideoImageCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    @IBOutlet weak var videoBackgroundView: UIView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingVideoText: UILabel!
    @IBOutlet weak var playButton: UIImageView!
    
    var indexPath : IndexPath?
    var player: AVPlayer?
    var isPlaying = false
    var currentVideo : AVPlayerLayer?
    
    @objc func playerDidFinishPlaying(note: NSNotification) {
        self.player?.seek(to: .zero)
        self.playButton.isHidden = false
        self.isPlaying = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(self, selector: #selector(self.pauseVideo), name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
    }
    
    override func prepareForReuse() {
        self.showLoadingScreen()
        if let video = currentVideo {
            video.removeFromSuperlayer()
        }
    }
    
    func addAccessibilityLabels() {
        self.videoBackgroundView.accessibilityLabel =  String(format: NSLocalizedString("video", comment: ""))
        self.loadingView.accessibilityLabel = String(format: NSLocalizedString("loading_video", comment: ""))
    }
    
    func videoLoaded() {
        self.playButton.isHidden = false
        self.loadingView.isHidden = true
    }
    
    func setColors() {
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.videoBackgroundView.backgroundColor = .clear
        loadingView.backgroundColor = .clear
        self.playButton.tintColor = .white
        self.playButton.image = self.playButton.image?.draw(withTintColor: .white)
        
        self.activityIndicator.color = Colors.fontNormal()
    }
    
    func showLoadingScreen() {
        self.setColors()
        
        videoBackgroundView.isHidden = true
        playButton.isHidden = true
        loadingView.isHidden = false
        activityIndicator.isHidden = false
        loadingVideoText.isHidden = false
        
        activityIndicator.startAnimating()
        
        loadingVideoText.text = String(format: NSLocalizedString("loading_video", comment: ""))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.currentVideo?.frame = self.bounds
        self.videoBackgroundView.layer.sublayers?.first?.frame = self.bounds
    }
    
    func updateVideoWithAsset(asset : AVAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        self.player?.actionAtItemEnd = .pause
        
        let playerLayer = AVPlayerLayer()
        playerLayer.player = self.player
        playerLayer.frame = self.videoBackgroundView.frame
        playerLayer.videoGravity = .resizeAspect
        playerLayer.needsDisplayOnBoundsChange = true
        playerLayer.backgroundColor = UIColor.clear.cgColor
        
        self.videoBackgroundView.layer.addSublayer(playerLayer)
        self.currentVideo = playerLayer
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            DDLogError("Could not create AudioSession for .moviePlayback")
        }
        
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (timer) in
            if playerItem.status != .readyToPlay && playerItem.status != .failed {
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
        if self.isPlaying {
            self.pauseVideo()
        } else {
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
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
            self.togglePlaying()
        }
    }
}
