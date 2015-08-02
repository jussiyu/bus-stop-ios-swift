//
//  SelectedStopTableViewCell.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 23.7.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit

class SelectedStopTableViewCell: UITableViewCell {

  @IBOutlet weak var stopNameLabel: UILabel!
  @IBOutlet weak var distanceHintLabel: UILabel!
  @IBOutlet weak var closeButton: UIButton!
  @IBOutlet weak var delayLabel: UILabel!
  
  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
