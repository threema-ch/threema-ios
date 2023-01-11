//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

@objc class CompanyDirectoryViewController: ThemedViewController {
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var searchBar: SearchBarWithoutCancelButton!
    @IBOutlet var noEntriesFoundView: UIView!
    @IBOutlet var noEntriesFoundTitleLabel: UILabel!
    @IBOutlet var noEntriesFoundDescriptionLabel: UILabel!
    @IBOutlet var activeFiltersView: UIStackView!
    @IBOutlet var scrollView: UIScrollView!
    
    @objc var addContactActive = true
    var filterArray = [String]()

    private var contactsWithSections = [[CompanyDirectoryContact]]()
    private var sectionTitles = [String]()
    private var allSectionTitles = [String]()
    private var nextPage = 0
    private var showLoadMore = false
    private var searchString = ""
    private var resultArray = [CompanyDirectoryContact]()
    
    private let collation = UILocalizedIndexedCollation.current()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.sizeToFit()
        searchBar.placeholder = BundleUtil.localizedString(forKey: "companydirectory_placeholder")
        
        tableView.setupAutoAdjust()
        
        noEntriesFoundTitleLabel.text = BundleUtil.localizedString(forKey: "companydirectory_noentries_title")
        noEntriesFoundDescriptionLabel.text = BundleUtil
            .localizedString(forKey: "companydirectory_noentries_description")
        
        title = MyIdentityStore.shared()?.companyName
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let filterItem = UIBarButtonItem(
            image: BundleUtil.imageNamed("Filter"),
            style: .plain,
            target: self,
            action: #selector(filter)
        )
        if addContactActive == false {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancel)
            )
            navigationItem.rightBarButtonItem = filterItem
        }
        else {
            navigationItem.leftBarButtonItem = filterItem
        }
        
        searchBar.becomeFirstResponder()
        performSearch()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowFilterSegue" {
            if let destinationVC = segue.destination as? CompanyDirectoryCategoryViewController {
                destinationVC.companyDirectoryViewController = self
            }
        }
    }

    override func refresh() {
        super.refresh()
        
        updateColors()
        updateNoEntriesFound()
        setupFiltersView()
        tableView.reloadData()
    }
    
    override func updateColors() {
        super.updateColors()
        
        Colors.update(searchBar: searchBar)
        Colors.update(tableView: tableView)
        
        noEntriesFoundDescriptionLabel.textColor = Colors.textLight
    }
    
    func updateNoEntriesFound() {
        if !contactsWithSections.isEmpty {
            tableView.tableFooterView = nil
        }
        else {
            tableView.tableFooterView = noEntriesFoundView
            showLoadMore = false
        }
    }
    
    @objc private func performSearch() {
        var query = searchBar.text ?? ""
        let isQueryEmpty = query.trimmingCharacters(in: .whitespaces) == ""
        if isQueryEmpty,
           filterArray.isEmpty {
            contactsWithSections.removeAll()
            sectionTitles.removeAll()
            resultArray.removeAll()
            refresh()
            return
        }
        else if isQueryEmpty {
            // Query was empty but category filters were set
            query = "*"
        }
        
        searchBar.isLoading = true
        
        // call api to get the results
        searchString = query
        
        ServerAPIConnector().search(
            inDirectory: query,
            categories: filterArray,
            page: Int32(nextPage),
            for: LicenseStore.shared(),
            for: MyIdentityStore.shared(),
            onCompletion: { contacts, paging in
                self.showLoadMore = false
                self.resetResults()
                if contacts != nil {
                    if !contacts!.isEmpty {
                        for dict in contacts! {
                            let contact = CompanyDirectoryContact(dictionary: dict as! [AnyHashable: Any?])
                            self.resultArray.append(contact)
                        }
                        if UserSettings.shared().sortOrderFirstName == true {
                            let (arrayContacts, arrayTitles, allSectionTitles) = self.collation.partitionObjects(
                                array: self.resultArray,
                                collationStringSelector: #selector(getter: CompanyDirectoryContact.first)
                            )
                            self.contactsWithSections = arrayContacts as! [[CompanyDirectoryContact]]
                            self.sectionTitles = arrayTitles
                            self.allSectionTitles = allSectionTitles
                        }
                        else {
                            let (arrayContacts, arrayTitles, allSectionTitles) = self.collation.partitionObjects(
                                array: self.resultArray,
                                collationStringSelector: #selector(getter: CompanyDirectoryContact.last)
                            )
                            self.contactsWithSections = arrayContacts as! [[CompanyDirectoryContact]]
                            self.sectionTitles = arrayTitles
                            self.allSectionTitles = allSectionTitles
                        }
                        if let next = paging?["next"] as? Int {
                            if let total = paging?["total"] as? Int {
                                if total != self.resultArray.count {
                                    self.nextPage = next
                                    self.showLoadMore = true
                                }
                            }
                        }
                    }
                }
            
                self.refresh()
                self.searchBar.isLoading = false
            }
        ) { error in
            if let theError = (error as NSError?) {
                if theError.code == 100 {
                    UIAlertTemplate.showAlert(
                        owner: self,
                        title: BundleUtil.localizedString(forKey: "cannot_connect_title"),
                        message: BundleUtil.localizedString(forKey: "cannot_connect_message")
                    )
                }
            }
            
            self.refresh()
            self.searchBar.isLoading = false
        }
    }
    
    private func loadMore(cell: UITableViewCell) {
        let activityView = UIActivityIndicatorView(style: Colors.activityIndicatorViewStyle)
        activityView.startAnimating()
        cell.accessoryView = activityView
        ServerAPIConnector().search(
            inDirectory: searchString,
            categories: filterArray,
            page: Int32(nextPage),
            for: LicenseStore.shared(),
            for: MyIdentityStore.shared(),
            onCompletion: { contacts, paging in
                self.showLoadMore = false
                if contacts != nil {
                    if !contacts!.isEmpty {
                        for dict in contacts! {
                            let contact = CompanyDirectoryContact(dictionary: dict as! [AnyHashable: Any?])
                            self.resultArray.append(contact)
                        }
                        if UserSettings.shared().sortOrderFirstName == true {
                            let (arrayContacts, arrayTitles, allSectionTitles) = self.collation.partitionObjects(
                                array: self.resultArray,
                                collationStringSelector: #selector(getter: CompanyDirectoryContact.first)
                            )
                            self.contactsWithSections = arrayContacts as! [[CompanyDirectoryContact]]
                            self.sectionTitles = arrayTitles
                            self.allSectionTitles = allSectionTitles
                        }
                        else {
                            let (arrayContacts, arrayTitles, allSectionTitles) = self.collation.partitionObjects(
                                array: self.resultArray,
                                collationStringSelector: #selector(getter: CompanyDirectoryContact.last)
                            )
                            self.contactsWithSections = arrayContacts as! [[CompanyDirectoryContact]]
                            self.sectionTitles = arrayTitles
                            self.allSectionTitles = allSectionTitles
                        }
                        if let next = paging?["next"] as? Int {
                            if let total = paging?["total"] as? Int {
                                if total != self.resultArray.count {
                                    self.nextPage = next
                                    self.showLoadMore = true
                                }
                            }
                        }
                    }
                }
                activityView.stopAnimating()
                cell.accessoryView = nil
                self.refresh()
                self.searchBar.isLoading = false
            }
        ) { _ in
            activityView.stopAnimating()
            cell.accessoryView = nil
            self.searchBar.isLoading = false
        }
    }
    
    private func setupFiltersView() {
        if !filterArray.isEmpty {
            scrollView.frame = CGRect(
                x: scrollView.frame.origin.x,
                y: scrollView.frame.origin.y,
                width: scrollView.frame.size.width,
                height: 44.0
            )
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
        }
        else {
            scrollView.frame = CGRect(
                x: scrollView.frame.origin.x,
                y: scrollView.frame.origin.y,
                width: scrollView.frame.size.width,
                height: 0
            )
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
        }
        
        for tempView in activeFiltersView.subviews {
            tempView.removeFromSuperview()
        }
        activeFiltersView.layoutIfNeeded()
        
        var i = 0
        let catDict = MyIdentityStore.shared().directoryCategories as! [String: String]
        
        for category in filterArray {
            let filterLabel = createFilterLabel(text: catDict[category]!, index: i)
            activeFiltersView.addArrangedSubview(filterLabel)
            i += 1
        }
    }
    
    private func createFilterLabel(text: String, index: Int) -> UIStackView {
        let textWidth = text.widthOfString(usingFont: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.callout))
        let buttonWidth: CGFloat = 23.0
        let padding: CGFloat = 2.0
        
        let stackView = UIStackView(frame: CGRect(
            x: 0.0,
            y: 0.0,
            width: textWidth + buttonWidth + (padding * 2),
            height: activeFiltersView.frame.size.height
        ))
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.spacing = 2.0
        
        let textlabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: textWidth, height: 20.0))
        textlabel.textColor = Colors.text
        textlabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.callout)
        textlabel.text = text
        stackView.addArrangedSubview(textlabel)
        
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        let closeImage = UIImage(systemName: "xmark.square", compatibleWith: traitCollection)
        button.setImage(closeImage, for: .normal)
        button.tag = index
        button.imageView?.contentMode = .scaleAspectFit
        button.layer.cornerRadius = CGFloat(button.frame.size.width) / CGFloat(2.0)
        button.addTarget(self, action: #selector(removeTag(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(button)
        
        stackView.layoutIfNeeded()
        
        let size = CGSize(width: textWidth, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        let attributes = [NSAttributedString.Key.font: textlabel.font]
        let rectangleHeight = String(text)
            .boundingRect(
                with: size,
                options: options,
                attributes: attributes as [NSAttributedString.Key: Any],
                context: nil
            ).height

        let backgroundFrame = CGRect(
            x: stackView.frame.origin.x - (padding * 3),
            y: ((stackView.frame.size.height - rectangleHeight) / 2) - padding,
            width: stackView.frame.size.width + (padding * 2),
            height: rectangleHeight + (padding * 2)
        )
        let backgroundView = UIView(frame: backgroundFrame)
        backgroundView.layer.cornerRadius = 5
        backgroundView.backgroundColor = Colors.backgroundInverted
        
        stackView.insertSubview(backgroundView, at: 0)
        
        return stackView
    }
    
    @objc private func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func filter() {
        performSegue(withIdentifier: "ShowFilterSegue", sender: self)
    }
    
    @objc private func removeTag(_ sender: AnyObject) {
        filterArray.remove(at: sender.tag)
        performSearch()
    }
    
    private func resetResults() {
        contactsWithSections.removeAll()
        sectionTitles.removeAll()
        resultArray.removeAll()
        nextPage = 0
    }
}

// MARK: - UITableViewDataSource

extension CompanyDirectoryViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if showLoadMore {
            return sectionTitles.count + 1
        }
        return sectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if showLoadMore, section == sectionTitles.count {
            return 1
        }
        return contactsWithSections[section].count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if showLoadMore, indexPath.section == sectionTitles.count {
            return 50.0
        }
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if showLoadMore, indexPath.section == sectionTitles.count {
            let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "LoadMoreCell", for: indexPath)
            cell.textLabel?.text = BundleUtil.localizedString(forKey: "loadMore")
            let image = UIImage(named: "ArrowDown", in: Colors.textLight)
            cell.imageView?.image = image?.resizedImage(newSize: CGSize(width: 25.0, height: 25.0))
            cell.accessoryView = nil
            return cell
        }
        else {
            let cell: Old_CompanyDirectoryContactCell = tableView.dequeueReusableCell(
                withIdentifier: "Old_CompanyDirectoryContactCell",
                for: indexPath
            ) as! Old_CompanyDirectoryContactCell
            let contact = contactsWithSections[indexPath.section][indexPath.row]
            cell.addContactActive = addContactActive
            cell.contact = contact
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        Colors.update(cell: cell)
        if cell.isKind(of: Old_CompanyDirectoryContactCell.self) {
            (cell as! Old_CompanyDirectoryContactCell).updateColors()
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        UILocalizedIndexedCollation.current().sectionIndexTitles
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if showLoadMore, section == sectionTitles.count {
            return ""
        }
        return sectionTitles[section]
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if title == "*" {
            return sectionTitles.count
        }
        
        if sectionTitles.contains(title) == true {
            return sectionTitles.firstIndex(of: title) ?? 0
        }
        else {
            var tempIndex = 0
            for str in allSectionTitles {
                if sectionTitles.contains(str) == true {
                    tempIndex += 1
                }
                if str == title {
                    return tempIndex - 1
                }
            }
            return 0
        }
    }
}

// MARK: - UITableViewDelegate

extension CompanyDirectoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if nextPage > 0, indexPath.section == sectionTitles.count {
            let cell = tableView.cellForRow(at: indexPath)
            let activityIndicator = UIActivityIndicatorView(style: Colors.activityIndicatorViewStyle)
            activityIndicator.startAnimating()
            cell?.accessoryView = activityIndicator
            loadMore(cell: cell!)
        }
        else {
            let directoryContact = contactsWithSections[indexPath.section][indexPath.row]
            ContactStore.shared().addWorkContact(
                with: directoryContact.id,
                publicKey: directoryContact.pk,
                firstname: directoryContact.first,
                lastname: directoryContact.last,
                acquaintanceLevel: .direct
            )
            .done { contact in
                // show chat
                if let contact = contact {
                    self.navigationController?.dismiss(animated: true, completion: {
                        let info = [kKeyContact: contact, kKeyForceCompose: true] as [String: Any]
                        NotificationCenter.default.post(
                            name: NSNotification.Name(rawValue: kNotificationShowConversation),
                            object: nil,
                            userInfo: info
                        )
                    })
                }
            }
            .catch { error in
                DDLogError("Add work contact failed \(error)")
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension CompanyDirectoryViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // here you should call the function which will update your data source and reload table view (or other UI that you have)
        performSearch()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
        if searchText.count >= 3 || (!filterArray.isEmpty && searchText.contains("*")) {
            perform(#selector(performSearch), with: nil, afterDelay: 0.75)
        }
        else {
            contactsWithSections.removeAll()
            sectionTitles.removeAll()
            resultArray.removeAll()
            refresh()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
    }
}

class SearchBarWithoutCancelButton: UISearchBar {
    override func layoutSubviews() {
        super.layoutSubviews()
        setShowsCancelButton(false, animated: false)
    }
    
    public var textField: UITextField? {
        let subViews = subviews.flatMap(\.subviews)
        guard let textField = (subViews.filter { $0 is UITextField }).first as? UITextField else {
            return nil
        }
        return textField
    }
    
    public var activityIndicator: UIActivityIndicatorView? {
        textField?.leftView?.subviews.compactMap { $0 as? UIActivityIndicatorView }.first
    }
    
    var isLoading: Bool {
        get {
            activityIndicator != nil
        } set {
            if newValue {
                if activityIndicator == nil {
                    let newActivityIndicator = UIActivityIndicatorView(style: Colors.activityIndicatorViewStyle)
                    newActivityIndicator.backgroundColor = .clear
                    newActivityIndicator.startAnimating()
                    textField?.leftView?.addSubview(newActivityIndicator)
                    let leftViewSize = textField?.leftView?.frame.size ?? CGSize.zero
                    newActivityIndicator.center = CGPoint(x: leftViewSize.width / 2, y: leftViewSize.height / 2)
                }
            }
            else {
                activityIndicator?.removeFromSuperview()
            }
        }
    }
}

extension UITableView {
    func setupAutoAdjust() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardshown),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardhide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc func keyboardshown(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue {
            fitContentInset(inset: UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0))
        }
    }

    @objc func keyboardhide(_ notification: Notification) {
        if ((notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
            fitContentInset(inset: .zero)
        }
    }

    func fitContentInset(inset: UIEdgeInsets!) {
        contentInset = inset
        scrollIndicatorInsets = inset
    }
}

extension UILocalizedIndexedCollation {
    // func for partition array in sections
    func partitionObjects(array: [AnyObject], collationStringSelector: Selector) -> ([AnyObject], [String], [String]) {
        var unsortedSections = [[AnyObject]]()
        // 1. Create a array to hold the data for each section
        for _ in sectionTitles {
            unsortedSections.append([]) // appending an empty array
        }
        // 2. Put each objects into a section
        for item in array {
            let index: Int = section(for: item, collationStringSelector: collationStringSelector)
            unsortedSections[index].append(item)
        }
        // 3. sorting the array of each section
        var activeSectionTitles = [String]()
        var sections = [AnyObject]()
        for index in 0..<unsortedSections.count {
            if !unsortedSections[index].isEmpty {
                activeSectionTitles.append(sectionTitles[index])
                sections.append(sortedArray(
                    from: unsortedSections[index],
                    collationStringSelector: collationStringSelector
                ) as AnyObject)
            }
        }
        return (sections, activeSectionTitles, sectionTitles)
    }
}

extension String {
    
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        // swiftformat:disable:next redundantSelf
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
}
