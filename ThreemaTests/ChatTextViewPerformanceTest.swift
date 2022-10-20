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

/// Performance test for the formatting done in ChatTextView.
/// The baseline average was done on MacBook Pro (16-inch, 2019) with an 2.6 GHz 6-Core Intel Core i7 and 16 GB 2667 MHz DDR4 memory. No other applications except Xcode and the simulator were run.
class ChatTextViewPerformanceTest: XCTestCase {
    var mySema = DispatchSemaphore(value: 0)
    
    let options = XCTMeasureOptions()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        options.invocationOptions = .manuallyStart
        options.iterationCount = 20
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
            Quo dicta omnis nihil. Et laborum et voluptatibus et autem aut quis similique. Non similique quam aliquid beatae laudantium ipsam velit repellendus. Molestiae necessitatibus nisi alias ab incidunt. Totam ut aut illum enim autem deserunt hic. Lorem ipsum dolor sit amet, *consectetur adipiscing* elit. _Vivamus_ pharetra *tincidunt* semper. Nunc at libero et turpis ornare dignissim. Ut velit tellus, malesuada quis sollicitudin eu, vestibulum sed ipsum. Donec tempus volutpat metus, *vitae tincidunt* velit _pellentesque_ vel. Ut diam felis, _ullamcorper_ *ut* fringilla et, maximus eget libero. *Aliquam eget.* Get *more* at https://lipsum.com/feed/html.
            """
        
        measure(options: options) {
            startMeasuring()
            for _ in 0...50 {
                let expectation = XCTestExpectation(description: "All calls to formattedString are done")
                
                runPerformanceTest(expectation: expectation, baseText: testText, appendText: testAppendText)
                
                wait(for: [expectation], timeout: 120.0)
            }
        }
    }
    
    func testUnformattedPerformance() throws {
        // This is an example of a performance test case.
        
        let testText = ""
        
        let testAppendText =
            "Quo dicta omnis nihil. Et laborum et voluptatibus et autem aut quis similique. Non similique quam aliquid beatae laudantium ipsam velit repellendus. Molestiae necessitatibus nisi alias ab incidunt. Totam ut aut illum enim autem deserunt hic. Provident autem animi et minima aperiam eos voluptatem. Sed maiores nostrum ut perferendis quibusdam deleniti eaque. Ut nesciunt non vero omnis molestias soluta vel itaque. Sed et cumque et fugit id esse dolore. Consequatur dolorem eos accusantium sint suscipit et necessitatibus eaque. Perspiciatis et eos dolor et est repellat recusandae quia."
        
        measure(options: options) {
            startMeasuring()
            for _ in 0...100 {
                let expectation = XCTestExpectation(description: "All calls to formattedString are done")
                
                runPerformanceTest(expectation: expectation, baseText: testText, appendText: testAppendText)
                
                wait(for: [expectation], timeout: 120.0)
            }
        }
    }
    
    func testSingleFormatPerformance() throws {
        // This is an example of a performance test case.
        
        let testText = ""
        
        let testAppendText =
            " Autem ad est iste rerum rerum qui quia minima. Alias ullam et totam dolorum inventore nihil aut minus. Consequuntur necessitatibus excepturi ut aut ex consequatur ipsum sunt. Est cumque officiis et cumque. Nulla veritatis praesentium id rerum. Consequatur et odio nihil quisquam molestias perferendis enim. Numquam sed cupiditate dicta id qui quibusdam dolorem. Sint delectus adipisci velit pariatur. Sed tempora alias fugit. Atque iste tenetur debitis. Beatae ea eum et qui. Ut sunt et dolorum quisquam unde qui. Aut qui facere neque ipsam voluptatem officiis sed quam. Asperiores aut eligendi molestiae quo cum nisi soluta aspernatur. Aliquam tenetur laudantium officiis sunt aut rerum omnis. Occaecati nihil sed eligendi maxime corrupti nostrum. Adipisci in perferendis et ut veritatis sed ratione. Velit earum est omnis unde ipsam adipisci dolores corporis. Et id id tempora qui. Enim facere consequatur ipsam qui maiores reprehenderit doloremque aliquam. Doloremque ex eum voluptatem. A sed labore illo sed ad asperiores esse. Alias quasi fuga est voluptatum animi nobis minus vel.Quo dicta omnis nihil. Et laborum et voluptatibus et autem aut quis similique. Non similique quam aliquid beatae laudantium ipsam velit repellendus. Molestiae necessitatibus nisi alias ab incidunt. Totam ut aut illum enim autem deserunt hic. Provident autem animi et minima aperiam eos voluptatem. *Sed maiores nostrum ut perferendis quibusdam deleniti eaque.* Ut _nesciunt_ non vero omnis molestias soluta vel itaque. ~Sed et cumque et fugit id esse dolore. Consequatur dolorem eos accusantium sint suscipit et necessitatibus eaque.~ _*Perspiciatis*_ *et eos* dolor et est repellat recusandae quia. https://en.wikipedia.org/wiki/Lorem_ipsum"
        
        measure(options: options) {
            startMeasuring()
            for _ in 0...10 {
                let expectation = XCTestExpectation(description: "All calls to formattedString are done")
                
                runPerformanceTest(expectation: expectation, baseText: testText, appendText: testAppendText)
                
                wait(for: [expectation], timeout: 120.0)
            }
        }
    }
    
    func testLongFormatPerformance() throws {
        let testText = """
                        Hello World! We have at least one link https://developer.apple.com/documentation/uikit/uitextviewdelegate/1618630-textview.
            Some *bold* text. Some _italic_ and some ~strikethrough~. We can also combine _italic_ and *bold* to _*bold and italic*_.
            """
        
        let testAppendText = """
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. In tincidunt euismod est, ut bibendum neque tristique vel. Fusce tempor justo a pulvinar convallis. Mauris accumsan, nisl nec fermentum ornare, nisl orci ullamcorper sem, in pretium leo lorem ut leo. Nam enim sapien, viverra vel semper eu, finibus ac leo. Integer lacus est, tristique vitae fermentum at, varius eu dolor. Donec et faucibus est, vel molestie lacus. Aenean massa nisi, vulputate vel varius laoreet, aliquam vitae diam. Sed eget mattis felis. Donec consectetur tempus leo et condimentum. Sed sit amet vulputate augue. Proin faucibus iaculis ligula, et volutpat metus. Maecenas interdum porttitor gravida. Fusce id lacus mattis, condimentum ligula ut, iaculis felis. Etiam in risus sit amet sem commodo bibendum.

            Fusce ut nisl et nisl ultrices facilisis. Cras varius quis lectus sit amet dignissim. Nam at nisi rutrum lacus laoreet pulvinar. Morbi aliquet tristique orci at rutrum. Vivamus vitae mi ac urna lobortis dignissim vel vel elit. Mauris pharetra quam eget ligula molestie cursus. Vestibulum at tortor eros.

            Praesent malesuada libero non sem feugiat, vitae elementum ipsum euismod. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Praesent vitae imperdiet elit. Nam semper, enim quis convallis imperdiet, augue orci egestas elit, ut feugiat nunc erat sed ipsum. Quisque id sapien dolor. Fusce nulla nunc, congue at justo consectetur, porttitor interdum metus. Phasellus venenatis eleifend dignissim. Nulla dapibus varius nulla, vulputate efficitur nisi dignissim a. Suspendisse potenti.

            Sed convallis, metus et dapibus varius, orci erat tincidunt ipsum, in condimentum leo lectus eu elit. Morbi at leo velit. Donec pharetra at felis quis suscipit. Ut maximus cursus sodales. Pellentesque ac fermentum tortor. Sed vulputate ex mi, nec tempus magna bibendum vitae. Vestibulum eget tellus at leo dapibus vehicula. Vivamus ac turpis quis leo laoreet eleifend. Duis iaculis varius magna, quis eleifend turpis. Morbi accumsan porta felis a fermentum.

            Aliquam a tincidunt lacus. Sed augue urna, posuere vel tellus eget, commodo ultrices est. Quisque congue non augue vel lobortis. Maecenas arcu nibh, eleifend ac semper laoreet, dapibus id enim. Integer pellentesque semper diam, non blandit nulla placerat a. In et quam vel ante mattis auctor sit amet non mauris. Suspendisse iaculis molestie dolor, non iaculis risus mollis ac. Maecenas ultrices risus leo, at luctus risus malesuada gravida. Mauris fringilla rhoncus urna, eget suscipit ligula malesuada sed. Sed sit amet eleifend ex, id iaculis purus. Vivamus pulvinar tincidunt ipsum, et porta libero dictum ut. Curabitur purus lacus, imperdiet quis elementum quis, imperdiet eu arcu. Cras posuere ligula sem, in scelerisque diam consectetur id. Sed dui eros, eleifend vel mollis at, fringilla a erat. Nunc elit diam, laoreet in ex ac, hendrerit pellentesque quam. Nullam varius condimentum massa, nec rutrum dolor efficitur et.

            Aenean massa mauris, congue eu sem id, ullamcorper pellentesque enim. Vestibulum in nulla ac dui sollicitudin consectetur. Mauris tempus eros libero. Sed eu feugiat elit, ut ultrices sem. Vivamus tortor odio, scelerisque at scelerisque nec, lacinia eget eros. Nam orci erat, vulputate et porttitor at, porta vel urna. Sed blandit ipsum sit amet nisi mollis tincidunt. Mauris vel lectus eu velit hendrerit facilisis vitae in nibh.

            Suspendisse condimentum justo ultrices augue feugiat, ut varius lacus lobortis. Quisque faucibus laoreet vehicula. Praesent volutpat nibh ut mattis sagittis. Integer elementum nisi in enim facilisis, nec pellentesque velit dictum. Duis ornare sit amet sem at imperdiet. Sed auctor rhoncus elit. Vestibulum rutrum varius ante sit amet semper. Pellentesque convallis imperdiet commodo.

            Nam diam velit, convallis laoreet eros non, vulputate ullamcorper lectus. Vestibulum feugiat blandit rhoncus. Nulla cursus rhoncus tristique. Pellentesque ut facilisis justo. Cras ultricies diam ultricies, aliquet nisl nec, porttitor enim. Fusce aliquam congue metus convallis luctus. Ut ut orci luctus, mollis tortor in, tempor ligula. Duis aliquam lacinia leo. Quisque pulvinar id ex non hendrerit. Suspendisse tortor arcu, ullamcorper et metus et, maximus molestie urna. Cras justo mauris, vestibulum at elit a, efficitur vulputate libero. Curabitur et bibendum mauris. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Interdum et malesuada fames ac ante ipsum primis in faucibus.

            Nulla venenatis molestie ornare. Integer magna mauris, suscipit et interdum sit amet, tempor a purus. Quisque vulputate imperdiet velit vitae malesuada. Sed hendrerit ipsum quis dui mattis, consequat hendrerit sapien ullamcorper. Quisque a tortor feugiat, faucibus augue non, sollicitudin ex. Nunc vel volutpat sapien. Vivamus id lorem metus. Maecenas eu venenatis massa. Duis laoreet turpis tellus, sit amet vestibulum risus sodales id. Aenean lectus odio, hendrerit quis laoreet eu, vestibulum dolor.
            """
        
        measure(options: options) {
            startMeasuring()
            for _ in 0...10 {
                let expectation = XCTestExpectation(description: "All calls to formattedString are done")
                
                runPerformanceTest(expectation: expectation, baseText: testText, appendText: testAppendText)
                
                wait(for: [expectation], timeout: 120.0)
            }
        }
    }
    
    func runPerformanceTest(expectation: XCTestExpectation, baseText: String, appendText: String) {
        mySema = DispatchSemaphore(value: 0)
        expectation.expectedFulfillmentCount = appendText.count + 1
        expectation.assertForOverFulfill = true
        
        let chatTextView = ChatTextView()

        DispatchQueue.global(qos: .default).async { [self] in
            chatTextView.chatTextViewDelegate = self
            
            DispatchQueue.main.async {
                let range = NSRange(location: 0, length: 0)
                let oldParsedText = NSMutableAttributedString(attributedString: chatTextView.attributedText!)
                let text = baseText
                let textView = chatTextView
                _ = chatTextView.formattedString(
                    range: range,
                    oldParsedText: oldParsedText,
                    text: text,
                    textView: textView
                )
                mySema.signal()
            }
            mySema.wait()
            expectation.fulfill()
            
            for i in 0...appendText.count - 1 {
                DispatchQueue.main.async {
                    let range = NSRange(location: chatTextView.attributedText.length, length: 0)
                    let oldParsedText = NSMutableAttributedString(attributedString: chatTextView.attributedText!)
                    let text = appendText[i, i + 1]
                    let textView = chatTextView
                    _ = chatTextView.formattedString(
                        range: range,
                        oldParsedText: oldParsedText,
                        text: text,
                        textView: textView
                    )
                    mySema.signal()
                }
                mySema.wait()
                expectation.fulfill()
            }
        }
    }
}

// MARK: - ChatTextViewDelegate

extension ChatTextViewPerformanceTest: ChatTextViewDelegate {
    func didEndEditing() { }
    
    func canStartEditing() -> Bool { true }
    
    func sendText() { }
    
    func chatTextView(_ textView: ChatTextView, shouldChangeTextIn range: NSRange, replacementText text: String) { }
    
    func chatTextViewDidChange(_ textView: ChatTextView) { }
}