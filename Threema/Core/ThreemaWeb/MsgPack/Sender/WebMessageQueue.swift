//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

import Foundation
import ThreemaFramework

protocol WebMessageQueueDelegate: AnyObject {
    func sendMessageToWeb(blacklisted: Bool, msgpack: Data, _ connectionInfo: Bool)
    func connectionStatus() -> WCConnectionState?
}

class WebMessageQueue: NSObject, NSCoding {
    
    weak var delegate: WebMessageQueueDelegate?
    var queue: [[String: Any]]
    var dispatchQueue: DispatchQueue
    
    override public init() {
        self.queue = [[String: Any]]()
        self.dispatchQueue = DispatchQueue(label: "ch.threema.webClientResponseQueue", attributes: [])
    }
    
    // MARK: NSCoding

    public required init?(coder aDecoder: NSCoder) {
        // super.init(coder:) is optional, see notes below
        self.delegate = aDecoder.decodeObject(forKey: "delegate") as? WebMessageQueueDelegate
        self.queue = aDecoder.decodeObject(forKey: "queue") as! [[String: Any]]
        self.dispatchQueue = DispatchQueue(label: "ch.threema.webClientResponseQueue", attributes: [])
    }
    
    public func encode(with aCoder: NSCoder) {
        // super.encodeWithCoder(aCoder) is optional, see notes below
        aCoder.encode(delegate, forKey: "delegate")
        aCoder.encode(queue, forKey: "queue")
    }
}

extension WebMessageQueue {
    // MARK: public functions
    
    func enqueue(data: Data?, blackListed: Bool, _ disconnectMessage: Bool = false) {
        dispatchQueue.async {
            self._enqueue(data: data, blackListed: blackListed, disconnectMessage: disconnectMessage)
        }
    }
    
    func enqueueWait(data: Data?, blackListed: Bool, _ disconnectMessage: Bool = false) {
        dispatchQueue.sync {
            self._enqueue(data: data, blackListed: blackListed, disconnectMessage: disconnectMessage)
        }
    }
    
    func processQueue() {
        for dict in queue {
            delegate?.sendMessageToWeb(blacklisted: dict["blacklisted"] as! Bool, msgpack: dict["data"] as! Data, false)
        }
    }
    
    func processSendFinished(finishedData: Data?) {
        dispatchQueue.async {
            var index = -1
            var i = 0
            for dict in self.queue {
                if let data = dict["data"] as? Data {
                    if data == finishedData {
                        index = i
                    }
                }
                i = i + 1
            }
            
            if index != -1 {
                self.queue.remove(at: index)
            }
        }
    }

    private func _enqueue(data: Data?, blackListed: Bool, disconnectMessage: Bool) {
        if data == nil {
            return
        }
        
        let dict = ["blacklisted": blackListed, "data": data!] as [String: Any]
        if delegate?.connectionStatus() == .ready {
            queue.append(dict)
            delegate?.sendMessageToWeb(blacklisted: blackListed, msgpack: data!, false)
        }
        else if disconnectMessage == true {
            queue.append(dict)
            delegate?.sendMessageToWeb(blacklisted: blackListed, msgpack: data!, true)
        }
        else {
            queue.append(dict)
        }
    }
    
    @objc func flush() {
        dispatchQueue.async {
            self.queue.removeAll()
        }
    }
}
