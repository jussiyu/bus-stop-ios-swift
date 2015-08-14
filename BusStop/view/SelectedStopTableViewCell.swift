//
//  SelectedStopTableViewCell.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 23.7.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit

protocol SelectedStopTableViewCellDelegate {
  func shouldSetFavorite(favorite: Bool) -> Bool
  func close()
}
class SelectedStopTableViewCell: UITableViewCell {
  
  var delegate: SelectedStopTableViewCellDelegate?

  @IBOutlet weak var stopNameLabel: UILabel!
  @IBOutlet weak var stopCountLabel: UILabel!
  @IBOutlet weak var distanceHintLabel: UILabel!
  @IBOutlet weak var closeButton: UIButton!
  @IBOutlet weak var delayLabel: UILabel!
  @IBOutlet weak var favoriteButton: UIButton!
  
  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

  @IBAction func favoriteButtonTapped(sender: AnyObject) {
    if let button = sender as? UIButton {
      if let delegate = delegate where delegate.shouldSetFavorite(button.selected) {
        button.selected = !button.selected
      }
      
    }
  }
  @IBAction func closeButtonTapped(sender: UIButton) {
    delegate?.close()
  }
}
