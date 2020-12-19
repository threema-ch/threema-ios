import UIKit
import AVFoundation

/**
 Cell representing video asset in Assets Collection Controller.
 */
class PPVideoViewCell: PPPhotoViewCell {
    var videoLayer: AVPlayerLayer?
    
    fileprivate lazy var indicator: UIActivityIndicatorView? = {
        let activity = UIActivityIndicatorView()
        activity.style = .whiteLarge
        activity.hidesWhenStopped = true
        return activity
    }()
    
    fileprivate lazy var videoInfoView: UIView = {
        let videoInfoView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 0))
        videoInfoView.backgroundColor = UIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.4)
        
        let videoImageView = UIImageView(image: DKImageResource.videoCameraIcon())
        videoInfoView.addSubview(videoImageView)
        videoImageView.center = CGPoint(x: videoImageView.bounds.width / 2 + 7, y: videoInfoView.bounds.height / 2)
        videoImageView.autoresizingMask = [.flexibleBottomMargin, .flexibleTopMargin]
        
        let videoDurationLabel = UILabel()
        videoDurationLabel.tag = -1
        videoDurationLabel.textAlignment = .right
        videoDurationLabel.font = UIFont.systemFont(ofSize: 12)
        videoDurationLabel.textColor = UIColor.white
        videoInfoView.addSubview(videoDurationLabel)
        videoDurationLabel.frame = CGRect(x: 0, y: 0, width: videoInfoView.bounds.width - 7, height: videoInfoView.bounds.height)
        videoDurationLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return videoInfoView
    }()
    
    fileprivate var videoRequestID: PHImageRequestID?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.addSublayer(videoInfoView.layer)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action:  #selector(PPVideoViewCell.longPressed(_:)))
        self.addGestureRecognizer(longPressRecognizer)

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setVideo(_ videoAsset: PHAsset) {
        
        if (videoAsset != asset) {
            self.set(videoAsset)
            
            let videoDurationLabel = self.videoInfoView.viewWithTag(-1) as! UILabel
            if videoAsset.duration > 0 {
                let minutes: Int = Int(videoAsset.duration) / 60
                let seconds: Int = Int(round(videoAsset.duration)) % 60
                videoDurationLabel.text = String(format: "\(minutes):%02d", seconds)
            }
        } else {
            self.setupCheckmark()
        }
    }
    
    func loadVideo() {
        let options: PHVideoRequestOptions = PHVideoRequestOptions.init()
        options.version = .current
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat
        if backgroundView != nil {
            if !(indicator?.isDescendant(of: backgroundView!))! {
                self.insertSubview(indicator!, aboveSubview: backgroundView!)
            }
        }
        
        indicator?.frame = CGRect(x: (self.frame.size.width/2)-20, y: (self.frame.size.height/2)-20, width: 40, height: 40)
        indicator?.startAnimating()
        
        videoRequestID = PHCachingImageManager.default().requestAVAsset(forVideo: asset!, options: options)
        { avasset, audioMix, info in
            if avasset != nil {
                DispatchQueue.main.sync {
                    let item = AVPlayerItem(asset: avasset!)
                    let player = AVPlayer(playerItem: item)
                    player.volume = 0.0
                    let playerLayer = AVPlayerLayer(player: player)
                    playerLayer.videoGravity = AVLayerVideoGravity.resize
                    
                    self.layer.insertSublayer(playerLayer, below: self.videoInfoView.layer)
                    playerLayer.frame = self.bounds
                    self.videoLayer = playerLayer
                    
                    self.startVideo()
                    
                    
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: nil, using: { (_) in
                        self.videoLayer?.player?.seek(to: CMTime.zero)
                        self.startVideo()
                    })
                }
            }
        }
    }

    func startVideo() {
        if videoLayer != nil {
            if self.videoLayer?.player?.currentItem?.status == .readyToPlay && self.indicator?.isAnimating == true {
                self.indicator?.stopAnimating()
            } else {
                if self.indicator?.isAnimating == false {
                    self.indicator?.startAnimating()
                }
            }
            self.videoLayer?.player?.play()
        } else {
            loadVideo()
        }
    }
    
    func stopVideo() {
        if let videoLayer = videoLayer {
            self.indicator?.stopAnimating()
            videoLayer.player?.pause()
        } else {
            self.indicator?.stopAnimating()
            PHCachingImageManager.default().cancelImageRequest(videoRequestID!)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if let videoLayer = videoLayer {
            videoLayer.removeFromSuperlayer()
            self.videoLayer = nil
            
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let height: CGFloat = 30
        self.videoInfoView.frame = CGRect(x: 0, y: self.contentView.bounds.height - height,
                                          width: self.contentView.bounds.width, height: height)
        
        videoLayer?.frame = bounds
    }
    
    private func is3DTouchAvailable() -> Bool
    {
        return self.traitCollection.forceTouchCapability == .available
    }
    
    @objc func longPressed(_ sender: UIGestureRecognizer)
    {
        if sender.state == .began {
            startVideo()
        }
        if sender.state == .ended {
            stopVideo()
        }
    }
}
