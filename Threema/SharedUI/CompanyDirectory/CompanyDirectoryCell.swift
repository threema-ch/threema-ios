import Foundation

class CompanyDirectoryCell: UITableViewCell, Reusable {
    
    private lazy var companyDirectoryView = CompanyDirectoryCellView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(companyDirectoryView)
        companyDirectoryView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            companyDirectoryView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            companyDirectoryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            companyDirectoryView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            companyDirectoryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
        ])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
