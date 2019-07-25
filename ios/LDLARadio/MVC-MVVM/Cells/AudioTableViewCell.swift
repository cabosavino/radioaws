//
//  AudioTableViewCell.swift
//  LDLARadio
//
//  Created by Javier Fuchs on 1/6/17.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit
import AlamofireImage
import JFCore

class AudioTableViewCell: UITableViewCell {
    // MARK: Properties
    
    static let reuseIdentifier = "AudioTableViewCellIdentifier"
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var logoView: UIImageView!
    @IBOutlet weak var downloadStateLabel: UILabel!
    @IBOutlet weak var downloadProgressView: UIProgressView!
    @IBOutlet weak var bookmarkButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    weak var delegate: AudioTableViewCellDelegate?
    
    var model : AudioViewModel? = nil {
        didSet {
            downloadStateLabel.text = model?.detail
            downloadStateLabel.textColor = model?.detailColor
            downloadStateLabel.font = model?.detailFont
            subtitleLabel.text = model?.subTitle
            subtitleLabel.textColor = model?.subTitleColor
            subtitleLabel.font = model?.subTitleFont
            titleLabel.text = model?.title
            titleLabel.textColor = model?.titleColor
            titleLabel.font = model?.titleFont
            logoView.image = model?.placeholderImage
            if let thumbnailUrl = model?.thumbnailUrl {
//                logoView.af_setImage(withURL: thumbnailUrl, placeholderImage: model?.placeholderImage)
                logoView.alpha = 0.5
                logoView.af_setImage(withURL: thumbnailUrl, placeholderImage: model?.placeholderImage) { (response) in
                    if response.error != nil {
                        self.logoView.alpha = 0.5
                    }
                    else {
                        self.logoView.alpha = 1.0
                    }
                }
            }
            bookmarkButton.isHighlighted = model?.isBookmarked ?? false
            selectionStyle = model?.selectionStyle ?? .none
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        subtitleLabel.text = ""
        titleLabel.text = ""
        logoView.image = nil
        downloadStateLabel.text = ""
        downloadProgressView.isHidden = true
        playButton.isHighlighted = false
        bookmarkButton.isHighlighted = false
    }
    
    @IBAction func playAction(_ sender: UIButton?) {
        if sender == playButton {
            delegate?.audioTableViewCell(self, didPlay: true)
        }
        else {
            fatalError()
        }
    }

    @IBAction func bookmarkAction(_ sender: UIButton?) {
    
        if sender == bookmarkButton {
            bookmarkButton.isHighlighted = !bookmarkButton.isHighlighted
            delegate?.audioTableViewCell(self, bookmarkDidChange: bookmarkButton.isHighlighted)
        }
        else {
            fatalError()
        }
    }

}

protocol AudioTableViewCellDelegate: class {
    
    func audioTableViewCell(_ cell: AudioTableViewCell, downloadStateDidChange newState: Stream.DownloadState)

    func audioTableViewCell(_ cell: AudioTableViewCell, bookmarkDidChange newState: Bool)

    func audioTableViewCell(_ cell: AudioTableViewCell, didPlay newState: Bool)
}
