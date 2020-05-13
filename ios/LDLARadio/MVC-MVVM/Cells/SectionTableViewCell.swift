//
//  SectionTableViewCell.swift
//  LDLARadio
//
//  Created by fox on 13/07/2019.
//  Copyright © 2019 Mobile Patagonia. All rights reserved.
//

import Foundation
import UIKit

class SectionTableViewCell: UITableViewCell {
    static let reuseIdentifier: String = "SectionTableViewCell"

    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var detailView: UILabel!
    @IBOutlet weak var thumbnailView: UIImageView!
    @IBOutlet weak var infoButton: UIButton!

    var infoBlock: ((_ catalogViewModel: SectionViewModel?) -> Void)?
    var actionBookmarkBlock: ((_ catalogViewModel: SectionViewModel?, _ isBookmarking: Bool) -> Void)?

    var model: SectionViewModel? = nil {
        didSet {
            guard let model = model else { return }
            infoButton.isHidden = model.text?.isEmpty ?? false

            detailView.text = model.title.text
            detailView.textColor = model.title.color
            detailView.font = model.title.font
            selectionStyle = model.selectionStyle
            accessoryType = model.accessoryType
            separatorView.isHidden = !model.showSeparator

            thumbnailView.image = model.placeholderImage
            if let thumbnailUrl = model.thumbnailUrl {
                thumbnailView.isHidden = false
                thumbnailView.af_setImage(withURL: thumbnailUrl, placeholderImage: model.placeholderImage) { (response) in
                    if response.error != nil {
                        self.thumbnailView.isHidden = true
                    } else {
                        self.portraitThumbnail()
                    }
                }
            } else {
                thumbnailView.isHidden = true
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        portraitThumbnail()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.isHidden = true
        detailView.text = nil
        detailView.textColor = .red
        selectionStyle = .none
        accessoryType = .none
        infoButton.isHidden = true
    }

    @IBAction func infoAction(_ sender: UIButton?) {

        if sender == infoButton {
            infoBlock?(model)
        } else {
            fatalError()
        }
    }

    private func portraitThumbnail() {
        thumbnailView?.layer.borderColor = UIColor.lightGray.cgColor
        thumbnailView?.layer.borderWidth = 1
        if let width = thumbnailView?.layer.bounds.size.width {
            thumbnailView?.layer.cornerRadius = width / 2
        }
    }

}
