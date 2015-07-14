//
//  VehicleHeaderView.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 13.7.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit

class VehicleHeaderView: UIView {
  
  @IBOutlet weak var view: UIView!
  @IBOutlet weak var lineLabel: UILabel!
  @IBOutlet weak var vehicleLabel: UILabel!
  @IBOutlet weak var vehicleDistanceLabel: UILabel!

  convenience init(lineRef: String, vehicleRef: String, distance: String) {
    var frame = CGRectZero
    self.init(frame: frame)
//    self.backgroundColor = UIColor.redColor()
    let xibView = NSBundle.mainBundle().loadNibNamed(self.nameOfClass, owner: self, options: nil).first as! UIView
    
    lineLabel.text = lineRef
    vehicleLabel.text = vehicleRef
    vehicleDistanceLabel.text = distance.stringByReplacingOccurrencesOfString("\\n", withString: "\n", options: nil)
    
    xibView.setTranslatesAutoresizingMaskIntoConstraints(false)
    
    addSubview(xibView)
    self.addConstraint(NSLayoutConstraint(item: xibView, attribute: .Leading, relatedBy: .Equal, toItem: self, attribute: .Leading, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: xibView, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: xibView, attribute: .Top, relatedBy: .Equal, toItem: self, attribute: .Top, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: xibView, attribute: .Bottom, relatedBy: .Equal, toItem: self, attribute: .Bottom, multiplier: 1.0, constant: 0.0))
    
    // Increase font sizes of the labels
    let lineLabelFont = UIFont(descriptor: UIFontDescriptor.preferredDescriptorWithStyle(UIFontTextStyleHeadline, oversizedBy: 16), size: 0)
    lineLabel.font = lineLabelFont
    let vehicleLabelFont = UIFont(descriptor: UIFontDescriptor.defaultDescriptorWithStyle(UIFontTextStyleSubheadline, oversizedBy: 10), size: 0)
    vehicleLabel.font = vehicleLabelFont
    
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  required init(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }
    
}

extension VehicleHeaderView: Printable, DebugPrintable{
  override var description: String {
    return "** VehicleHeaderView: \(lineLabel.text!), \(vehicleLabel.text!), \(vehicleDistanceLabel.text!)"
  }

  override var debugDescription: String {
    return "** VehicleHeaderView: \(lineLabel!.text), \(vehicleLabel!.text), \(vehicleDistanceLabel!.text)"
  }
}