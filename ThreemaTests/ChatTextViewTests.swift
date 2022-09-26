//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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

import XCTest
@testable import Threema

class ChatTextViewTests: XCTestCase {
    let mySema = DispatchSemaphore(value: 0)
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testBasicPerformance() throws {
        let testText = """
                        Hello World! We have at least one link https://developer.apple.com/documentation/uikit/uitextviewdelegate/1618630-textview.
            Some *bold* text. Some _italic_ and some ~strikethrough~. We can also combine _italic_ and *bold* to _*bold and italic*_.
            """
        
        let testAppendText = """
            Lorem ipsum dolor sit amet, *consectetur adipiscing* elit. _Vivamus_ pharetra *tincidunt* semper. Nunc at libero et turpis ornare dignissim. Ut velit tellus, malesuada quis sollicitudin eu, vestibulum sed ipsum. Donec tempus volutpat metus, *vitae tincidunt* velit _pellentesque_ vel. Ut diam felis, _ullamcorper_ *ut* fringilla et, maximus eget libero. *Aliquam eget.* Get *more* at https://lipsum.com/feed/html.
            """
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            
            let chatTextView = ChatTextView()
            chatTextView.chatTextViewDelegate = self
            
            startMeasuring()
            
            _ = chatTextView.textView(
                chatTextView,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementText: testText
            )
            mySema.wait()
            
            for i in 0...testAppendText.count - 1 {
                _ = chatTextView.textView(
                    chatTextView,
                    shouldChangeTextIn: NSRange(location: chatTextView.attributedText.length, length: 0),
                    replacementText: testAppendText[i, i + 1]
                )
                mySema.wait()
            }
        }
    }
    
    func testUnformattedPerformance() throws {
        // This is an example of a performance test case.
        
        let testText = ""
        
        let testAppendText =
            "Provident autem animi et minima aperiam eos voluptatem. Sed maiores nostrum ut perferendis quibusdam deleniti eaque. Ut nesciunt non vero omnis molestias soluta vel itaque. Sed et cumque et fugit id esse dolore. Consequatur dolorem eos accusantium sint suscipit et necessitatibus eaque. Perspiciatis et eos dolor et est repellat recusandae quia."
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let chatTextView = ChatTextView()
            chatTextView.chatTextViewDelegate = self
            
            startMeasuring()
            
            _ = chatTextView.textView(
                chatTextView,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementText: testText
            )
            mySema.wait()
            
            for i in 0...testAppendText.count - 1 {
                _ = chatTextView.textView(
                    chatTextView,
                    shouldChangeTextIn: NSRange(location: chatTextView.attributedText.length, length: 0),
                    replacementText: testAppendText[i, i + 1]
                )
                mySema.wait()
            }
        }
    }
    
    func testSingleFormatPerformance() throws {
        // This is an example of a performance test case.
        
        let testText = ""
        
        let testAppendText =
            "Provident autem animi et minima aperiam eos voluptatem. *Sed maiores nostrum ut perferendis quibusdam deleniti eaque.* Ut _nesciunt_ non vero omnis molestias soluta vel itaque. ~Sed et cumque et fugit id esse dolore. Consequatur dolorem eos accusantium sint suscipit et necessitatibus eaque.~ _*Perspiciatis*_ *et eos* dolor et est repellat recusandae quia. https://en.wikipedia.org/wiki/Lorem_ipsum"
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            
            let chatTextView = ChatTextView()
            chatTextView.chatTextViewDelegate = self
            
            startMeasuring()
            
            _ = chatTextView.textView(
                chatTextView,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementText: testText
            )
            mySema.wait()
            
            for i in 0...testAppendText.count - 1 {
                _ = chatTextView.textView(
                    chatTextView,
                    shouldChangeTextIn: NSRange(location: chatTextView.attributedText.length, length: 0),
                    replacementText: testAppendText[i, i + 1]
                )
                mySema.wait()
            }
        }
    }
}

// MARK: - ChatTextViewDelegate

extension ChatTextViewTests: ChatTextViewDelegate {
    func chatTextView(_ textView: ChatTextView, shouldChangeTextIn range: NSRange, replacementText text: String) {
        mySema.signal()
    }
    
    func chatTextViewDidChange(_ textView: ChatTextView) { }
}
