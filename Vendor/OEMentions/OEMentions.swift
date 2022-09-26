//
//  OEMentions.swift
//  OEMentions
//
//  Created by Omar Alessa on 7/31/16.
//  Copyright © 2016 omaressa. All rights reserved.
//

import UIKit

protocol OEMentionsDelegate
{
    // To respond to the selected name
    func mentionSelected(id:Int, name:String)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath, oeObject: OEObject) -> UITableViewCell
    func tableViewPositionUpdated()
    func textViewShouldUpdateTextColor()
}


class OEMentions: NSObject, UITextViewDelegate, UITableViewDelegate, UITableViewDataSource {
    
    // UIViewController view
    var mainView:UIView?
    
    // UIView for the textview container
    var containerView:UIView?
    
    // The UITextView we want to add mention to
    var textView:UITextView?
    
    // List of names to show in the list
    private var oeObjects:[OEObject]?
    
    // [Index:Length] of added mentions to textview
    var mentionsIndexes = [Int:[String: Any]]()
    
    // Keep track if still searching for a name
    var isMentioning = Bool()
    
    // The search query
    var mentionQuery = String()
    
    // The start of mention index
    var startMentionIndex = Int()
    
    // Character that show the mention list (Default is "@"), It can be changed using changeMentionCharacter func
    private var mentionCharater = "@"
    
    // Keyboard hieght after it shows
    var keyboardHieght:CGFloat?
    
    
    // Mentions tableview
    var tableView: UITableView!
    
    //MARK: Customizable mention list properties
    
    // Color of the mention tableview name text
    var nameColor = UIColor.blue
    
    // Font of the mention tableview name text
    var nameFont = UIFont.boldSystemFont(ofSize: 14.0)
    
    // Color if the rest of the UITextView text
    var notMentionColor = UIColor.black
    
    // OEMention table view full in container view
    var showMentionFullInContainer:Bool = true
    
    private var filteredOEObjects: [OEObject]?
    
    
    // OEMention Delegate
    var delegate:OEMentionsDelegate?
    
    var textViewWidth:CGFloat?
    var textViewHeight:CGFloat?
    var textViewYPosition:CGFloat?
    
    var containerHieght:CGFloat?
    
    //MARK: class init without container
    init(textView:UITextView, mainView:UIView, oeObjects:[OEObject]){
        super.init()
        
        self.mainView = mainView
        self.setOeObjects(oeObjects: oeObjects)
        self.textView = textView
        
        self.textViewWidth = textView.frame.width
        
        initMentionsList()
        
        NotificationCenter.default.addObserver(self, selector: #selector(OEMentions.keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    //MARK: class init with container
    init(containerView:UIView, textView:UITextView, mainView:UIView, oeObjects:[OEObject]){
        super.init()
        
        self.containerView = containerView
        self.mainView = mainView
        self.setOeObjects(oeObjects: oeObjects)
        self.textView = textView
        
        self.containerHieght = containerView.frame.height
        
        self.textViewWidth = textView.frame.width
        self.textViewHeight = textView.frame.height
        self.textViewYPosition = textView.frame.origin.y
        
        initMentionsList()
        
        NotificationCenter.default.addObserver(self, selector: #selector(OEMentions.keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    func setOeObjects(oeObjects: [OEObject]?) {
        self.oeObjects = oeObjects
        self.filteredOEObjects = oeObjects
    }
    
    
    // Set the mention character. Should be one character only, default is "@"
    func changeMentionCharacter(character: String){
        if character.count == 1 && character != " " {
            self.mentionCharater = character
        }
    }
    
    // Change tableview background color
    func changeMentionTableviewBackground(color: UIColor){
        self.tableView.backgroundColor = color
    }
    
    func changeMentionTableviewSeparatorColor(color: UIColor) {
        self.tableView.separatorColor = color
    }
    
    
    //MARK: UITextView delegate functions:
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        self.mentionQuery = ""
        self.isMentioning = false
        UIView.animate(withDuration: 0.2, animations: {
            self.tableView.isHidden = true
        })
        
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        self.textView!.isScrollEnabled = false
        self.textView!.sizeToFit()
        self.textView!.frame.size.width = textViewWidth!
        
        updatePosition()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let str = String(textView.text)
        var lastCharacter = "nothing"
        
        if !str.isEmpty && range.location != 0{
            lastCharacter = String(str[str.index(before: str.endIndex)])
        }
        
        // Check if there is mentions
        if mentionsIndexes.count != 0 {
            var indexDiff = 0
            for (index,dict) in mentionsIndexes {
                let length = dict["length"] as! Int
                if case index+1 ... index+length-1 = range.location {
                    // If start typing within a mention rang delete that name:
                    mentionsIndexes.removeValue(forKey: index)
                    indexDiff += -length
                    textView.replace(textView.textRangeFromNSRange(range: NSMakeRange(index, length))!, withText: "")
                }
                else if (range.location + range.length < index+length) && (range.location + range.length > index) {
                    mentionsIndexes.removeValue(forKey: index)
                }
                else if (index > range.location && index+length <= range.location + range.length) || (range.location < index + length && range.location + range.length >= index+length) {
                    mentionsIndexes.removeValue(forKey: index)
                }
                else if index >= range.location && range.length == 0 {
                    mentionsIndexes.removeValue(forKey: index)
                    mentionsIndexes[index + indexDiff + text.utf16.count] = dict
                }
                else if index >= range.location && range.length > 0 {
                    mentionsIndexes.removeValue(forKey: index)
                    mentionsIndexes[index + indexDiff + text.utf16.count - range.length] = dict
                }
                else if index < 0 {
                    mentionsIndexes.removeValue(forKey: index)
                }
                
                if case index+length = range.location {
                    // If start typing within a mention rang delete that name:
                    delegate?.textViewShouldUpdateTextColor()
                }
            }
        }
        
        if isMentioning {
            if text == " " || (text.count == 0 &&  self.mentionQuery == ""){ // If Space or delete the "@"
                self.mentionQuery = ""
                self.isMentioning = false
                updateTableView()
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.tableView.isHidden = true
                    
                })
            }
            else if text.count == 0 {
                self.mentionQuery.remove(at: self.mentionQuery.index(before: self.mentionQuery.endIndex))
                updateTableView()
            }
            else {
                self.mentionQuery += text
                updateTableView()
            }
        } else {
            if text == self.mentionCharater && textView.markedTextRange == nil && ( range.location == 0 || lastCharacter == " " || range.length == 0 ) { /* (Beginning of textView) OR (space then @) */
                
                self.isMentioning = true
                self.startMentionIndex = range.location
                updateTableView()
                UIView.animate(withDuration: 0.2, animations: {
                    self.tableView.isHidden = false
                })
            }
        }
        
        return true
    }
    
    
    //MARK: Keyboard will show NSNotification:
    
    @objc func keyboardWillShow(notification:NSNotification) {
        
        let userInfo:NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame:NSValue = userInfo.value(forKey: UIResponder.keyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let thekeyboardHeight = keyboardRectangle.height
        self.keyboardHieght = thekeyboardHeight
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.updatePosition()
            
        })
        
    }
    
    
    //Mentions UITableView init
    func initMentionsList(){
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: self.mainView!.frame.width, height: 100), style: UITableView.Style.plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = true
        tableView.separatorColor = UIColor.clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.mainView!.addSubview(self.tableView)
        
        self.tableView.isHidden = true
    }
    
    
    //MARK: Mentions UITableView deleget functions:
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredOEObjects!.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell?
        if delegate != nil {
            cell = delegate?.tableView(tableView, cellForRowAt: indexPath, oeObject: filteredOEObjects![indexPath.row])
            if cell != nil {
                return cell!
            }
        }
        
        cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "cell")
        cell!.backgroundColor = UIColor.clear
        cell!.selectionStyle = UITableViewCell.SelectionStyle.none
        cell!.textLabel!.text = filteredOEObjects![indexPath.row].name
        cell!.textLabel!.textColor = nameColor
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedMention = filteredOEObjects?[indexPath.row] else {
            return
        }
        
        addMentionToTextView(oeObject: selectedMention)
        
        self.mentionQuery = ""
        self.isMentioning = false
        UIView.animate(withDuration: 0.2, animations: {
            self.tableView.isHidden = true
        })
        
        if delegate != nil {
            self.delegate!.mentionSelected(id: selectedMention.id, name: selectedMention.name)
        }
    }
    
    // Add a mention name to the UITextView
    func addMentionToTextView(oeObject: OEObject){
        let name = oeObject.name as String
        
        // add a space at the end and beginning of the mention (if needed)
        var mentionBeginChar = ""
        var mentionEndChat = ""
        if self.startMentionIndex > 0 {
            if let range = Range.init(NSMakeRange(self.startMentionIndex - 1, 1), in: self.textView!.text) {
                if self.textView!.text[range] != " " {
                    mentionBeginChar = " "
                }
            }
        }
        if self.startMentionIndex + self.mentionQuery.count + 1 < self.textView!.text.utf16.count {
            if let range = Range.init(NSMakeRange(self.startMentionIndex + self.mentionQuery.count + 1, 1), in: self.textView!.text) {
                if self.textView!.text[range] != " " {
                    mentionEndChat = " "
                }
            }
        } else {
            if self.startMentionIndex + self.mentionQuery.count + 1 == self.textView!.text.utf16.count {
                mentionEndChat = " "
            }
        }
        
        let dict = ["key": oeObject.key, "length": name.utf16.count] as [String : Any]
        let newStartMentionIndex = mentionBeginChar.utf16.count > 0 ? self.startMentionIndex+1 : self.startMentionIndex
        mentionsIndexes[newStartMentionIndex] = dict
        
        let range = NSRange.init(location: self.startMentionIndex, length: self.mentionQuery.count + 1)
        let swiftRange = Range.init(range, in: self.textView!.text)
        let replaceString = mentionBeginChar + oeObject.name + mentionEndChat
        self.textView!.text.replaceSubrange(swiftRange!, with: replaceString)
        
        let indexDiff = replaceString.utf16.count - 1
        if mentionsIndexes.count != 0 {
            for (index,dict) in mentionsIndexes {
                if index != newStartMentionIndex {
                    if index > range.location && range.length == 0 {
                        mentionsIndexes.removeValue(forKey: index)
                        mentionsIndexes[index + indexDiff] = dict
                    }
                    else if index > range.location && range.length > 0 {
                        mentionsIndexes.removeValue(forKey: index)
                        mentionsIndexes[index + indexDiff] = dict
                    }
                }
            }
        }
        
        if let theText = self.textView!.text {
            var attributes = [NSAttributedString.Key: AnyObject]()
            attributes[.foregroundColor] = notMentionColor
            attributes[.font] = nameFont
            
            let attributedString: NSMutableAttributedString = NSMutableAttributedString.init(string: theText, attributes: attributes)
            
            self.textView!.attributedText = attributedString
            if let cursorLocation = self.textView!.position(from: self.textView!.beginningOfDocument, offset: self.startMentionIndex + name.utf16.count + 1) {
                self.textView!.selectedTextRange = self.textView!.textRange(from: cursorLocation, to: cursorLocation)
            }
        }
        
        updatePosition()
    }
    
    
    // Update views potision for the textview and tableview
    func updatePosition(){
        if keyboardHieght == nil {
            return
        }
        if #available(iOS 11.0, *) {
            self.tableView.frame.size.width = mainView!.safeAreaLayoutGuide.layoutFrame.size.width
            self.tableView.frame.origin.x = mainView!.safeAreaLayoutGuide.layoutFrame.origin.x
        } else {
            self.tableView.frame.size.width = mainView!.frame.size.width
            self.tableView.frame.origin.x = mainView!.frame.origin.x
        }
        if containerView != nil {
            
            self.textView!.frame.origin.y = self.textViewYPosition!
            let fullTableViewHeight = UIScreen.main.bounds.height - self.keyboardHieght! - self.containerView!.frame.size.height
            if showMentionFullInContainer == true {
                if fullTableViewHeight != self.tableView.frame.size.height {
                    self.tableView.frame.size.height = fullTableViewHeight
                    self.tableView.frame.origin.y = 0
                }
            } else {
                if self.tableView.contentSize.height < fullTableViewHeight {
                    self.tableView.frame.size.height = self.tableView.contentSize.height
                    self.tableView.frame.origin.y = UIScreen.main.bounds.height - self.keyboardHieght! - containerView!.frame.size.height - self.tableView.frame.size.height
                } else {
                    if fullTableViewHeight != self.tableView.frame.size.height {
                        self.tableView.frame.size.height = fullTableViewHeight
                        self.tableView.frame.origin.y = 0
                    }
                }
            }
        }
        else {
            self.textView!.frame.origin.y = UIScreen.main.bounds.height - self.keyboardHieght! - self.textView!.frame.height
            self.tableView.frame.size.height = UIScreen.main.bounds.height - self.keyboardHieght! - self.textView!.frame.height
            self.tableView.frame.origin.y = 0
        }
        if delegate != nil {
            delegate!.tableViewPositionUpdated()
        }
    }
    
    private func updateTableView() {
        if mentionQuery.count > 0 {
            self.filteredOEObjects = self.oeObjects?.filter {
                $0.name.lowercased().localizedStandardContains(self.mentionQuery.lowercased()) || $0.key.lowercased().localizedStandardContains(self.mentionQuery.lowercased())
            }
        } else {
            self.filteredOEObjects = oeObjects
        }
        
        self.tableView.reloadData()
    }
}


// OEMentions object (id,name)

class OEObject {
    
    var id:Int
    var name:String
    var key:String
    var object: Any?
    
    init(id:Int, name:String, key: String, object: Any?){
        self.id = id
        self.name = name
        self.key = key
        self.object = object
    }
}


extension UITextView
{
    func textRangeFromNSRange(range:NSRange) -> UITextRange?
    {
        let beginning = self.beginningOfDocument
        guard let start = self.position(from: beginning, offset: range.location), let end = self.position(from: start, offset: range.length) else { return nil}
        return self.textRange(from: start, to: end)
    }
}
