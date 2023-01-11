//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

class DebugTableView: UITableView {
    
    override func insertRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        super.insertRows(at: indexPaths, with: animation)
        DDLogNotice("Insert rows at \(indexPaths)")
    }
    
    override func reconfigureRows(at indexPaths: [IndexPath]) {
        super.reconfigureRows(at: indexPaths)
        DDLogNotice("Reconfigure rows at \(indexPaths)")
    }
    
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        super.reloadRows(at: indexPaths, with: animation)
        DDLogNotice("Reload rows at \(indexPaths)")
    }
    
    override func deleteRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        super.deleteRows(at: indexPaths, with: animation)
        DDLogNotice("Delete rows at \(indexPaths)")
    }
    
    override func moveRow(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        super.moveRow(at: indexPath, to: newIndexPath)
        DDLogNotice("Move row at \(indexPath) to \(newIndexPath)")
    }
    
    override func insertSections(_ sections: IndexSet, with animation: UITableView.RowAnimation) {
        super.insertSections(sections, with: animation)
        DDLogNotice("insertSections \(sections)")
    }
    
    override func deleteSections(_ sections: IndexSet, with animation: UITableView.RowAnimation) {
        super.deleteSections(sections, with: animation)
        DDLogNotice("deleteSections \(sections)")
    }
    
    override func moveSection(_ section: Int, toSection newSection: Int) {
        super.moveSection(section, toSection: newSection)
        DDLogNotice("moveSection \(section) to \(newSection)")
    }
    
    override func reloadSections(_ sections: IndexSet, with animation: UITableView.RowAnimation) {
        super.reloadSections(sections, with: animation)
        DDLogNotice("reloadSections \(sections)")
    }
    
    override func reloadData() {
        super.reloadData()
        DDLogNotice("\(#function)")
    }
    
    override func performBatchUpdates(_ updates: (() -> Void)?, completion: ((Bool) -> Void)? = nil) {
        DDLogNotice("Start performBatchUpdates")
        super.performBatchUpdates(updates, completion: { val in
            completion?(val)
            DDLogNotice("End performBatchUpdates")
        })
    }
    
    override func layoutSubviews() {
        DDLogVerbose("Start \(#function)")
        defer { DDLogVerbose("End \(#function)") }
        
        super.layoutSubviews()
    }
    
    override func setNeedsLayout() {
        DDLogVerbose("\(#function)")
        super.setNeedsLayout()
    }
    
    override func scrollToRow(at indexPath: IndexPath, at scrollPosition: UITableView.ScrollPosition, animated: Bool) {
        DDLogVerbose("\(#function)")
        super.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }
    
    override var contentSize: CGSize {
        didSet {
            DDLogVerbose("\(#function) \(contentSize)")
        }
    }
    
    override var contentInset: UIEdgeInsets {
        didSet {
            DDLogVerbose("\(#function) \(contentInset)")
        }
    }
    
    override var contentOffset: CGPoint {
        didSet {
            DDLogVerbose("\(#function) \(contentOffset)")
        }
    }
    
    override func safeAreaInsetsDidChange() {
        DDLogVerbose("\(#function) \(safeAreaInsets)")
    }
    
    override var bounds: CGRect {
        didSet {
            DDLogVerbose("\(#function) \(bounds)")
        }
    }
    
    override var frame: CGRect {
        didSet {
            DDLogVerbose("\(#function) \(frame)")
        }
    }
}
