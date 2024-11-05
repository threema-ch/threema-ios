//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import MBProgressHUD
import ThreemaMacros

class ProgressViewHandler {
    let view: UIView
    let totalWorkItems: Int64
    let label: String
    
    var exportSession: AVAssetExportSession?
    
    init(view: UIView, totalWorkItems: Int, label: String) {
        self.view = view
        self.totalWorkItems = Int64(totalWorkItems) * 100
        self.label = label
        initProgress()
    }
    
    func initProgress() {
        DispatchQueue.main.async {
            let hud = MBProgressHUD(view: self.view)
            hud.graceTime = 0.5
            hud.minShowTime = 0.5
            self.view.addSubview(hud)
            hud.show(animated: true)
            
            if hud.progressObject == nil {
                hud.mode = .annularDeterminate
                
                let po = Progress(totalUnitCount: self.totalWorkItems)
                hud.progressObject = po
                
                hud.label.text = String.localizedStringWithFormat(
                    #localize("processing_items_progress"),
                    po.completedUnitCount / 100,
                    po.totalUnitCount / 100
                )
            }
        }
    }
    
    func incrementItemProgress(_ increment: Int) {
        incrementItemProgress(Int64(increment))
    }
    
    func incrementItemProgress(_ increment: Int64) {
        DispatchQueue.main.async {
            guard let hud = MBProgressHUD.forView(self.view) else {
                DDLogError("Could not increment progress on nil MBProgressHUD")
                return
            }
            
            guard let po = hud.progressObject else {
                DDLogError("Could not increment progress on nil progressObject")
                return
            }
            hud.mode = .annularDeterminate
            po.completedUnitCount += Int64(increment)
            let completed = min(po.completedUnitCount / 100 + 1, po.totalUnitCount / 100)
            let total = po.totalUnitCount / 100
            hud.label.text = String.localizedStringWithFormat(
                #localize("processing_items_progress"),
                completed,
                total
            )
            hud.label.font = UIFont.monospacedDigitSystemFont(ofSize: hud.label.font.pointSize, weight: .semibold)
        }
    }
    
    func observeVideoItem(_ videoItem: VideoPreviewItem) {
        var prevProgress = 0
        DispatchQueue.main.async {
            _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if let exportSession = videoItem.exportSession {
                    let prog = Int(min(exportSession.progress, 0.9) * 100)
                    let increment = prog - prevProgress
                    if increment >= 1 {
                        prevProgress = prog
                    }
                    self.incrementItemProgress(increment)
                    if exportSession.progress == 1.0 || videoItem.isConverted {
                        self.incrementItemProgress(max(90 - Int(prevProgress * 100), 0))
                        timer.invalidate()
                    }
                }
                else {
                    timer.invalidate()
                }
            }
        }
    }
    
    func finishVideo() {
        incrementItemProgress(10)
    }
    
    func hideHud(delayed: Bool = false, completion: @escaping () -> Void) {
        var deadlineTime = DispatchTime.now()
        if delayed {
            deadlineTime = DispatchTime.now() + DispatchTimeInterval.milliseconds(300)
        }
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            MBProgressHUD.hide(for: self.view, animated: true)
            completion()
        }
    }
}
