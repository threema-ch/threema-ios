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

import UIKit

protocol TimePickerDelegate: class {
    func didChangeTime(date: Date, indexPath: IndexPath)
}

class TimePickerwCell: UITableViewCell {

    @IBOutlet weak var timePicker: UIDatePicker!
    
    var indexPath: IndexPath!
    weak var delegate: TimePickerDelegate?
    
    // Reuse identifier
    class func reuseIdentifier() -> String {
        return "TimePickerCell"
    }
    
    class func nibName() -> String {
        return "TimePickerCell"
    }
    
    // Cell height
    class func cellHeight() -> CGFloat {
        return 162.0
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initView()
    }
    
    func initView() {
        timePicker.addTarget(self, action: #selector(dateDidChange), for: .valueChanged)
    }

    
    func updateCell(date: Date, indexPath: IndexPath) {
        timePicker.setDate(date, animated: true)
        self.indexPath = indexPath
    }
    
    @objc func dateDidChange(_ sender: UIDatePicker) {
        let indexPathForDisplayTime = IndexPath(row: indexPath.row - 1, section: indexPath.section)
        delegate?.didChangeTime(date: sender.date, indexPath: indexPathForDisplayTime)
    }

}
