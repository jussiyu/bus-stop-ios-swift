//
//  VehicleHeaderView.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 13.7.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit

class VehicleHeaderView: UIView {
  
  var lineLabel: UILabel!
  var vehicleLabel: UILabel!
  var vehicleDistanceLabel: UILabel!
  
  static let defaultWidth: CGFloat = 200
  var widthExtra: CGFloat = 0
  
  convenience init(lineRef: String, vehicleRef: String, distance: String) {
    var frame = CGRectZero
    self.init(frame: frame)
    self.setContentHuggingPriority(0, forAxis: .Horizontal)

    lineLabel = UILabel()
    lineLabel.textAlignment = NSTextAlignment.Center
    lineLabel.text = lineRef
    vehicleLabel = UILabel()
    vehicleLabel.textAlignment = NSTextAlignment.Center
    vehicleLabel.text = vehicleRef
    vehicleDistanceLabel = UILabel()
    vehicleDistanceLabel.textAlignment = NSTextAlignment.Center
    vehicleDistanceLabel.text = distance.stringByReplacingOccurrencesOfString("\\n", withString: "\n", options: nil)
    vehicleDistanceLabel.numberOfLines = 2
    
    // add child views
    addSubview(lineLabel)
    addSubview(vehicleLabel)
    addSubview(vehicleDistanceLabel)

    // Constraints
    lineLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
    vehicleLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
    vehicleDistanceLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-[a]-[b]-[c]-|", options: nil, metrics: [:], views: ["a":lineLabel, "b":vehicleLabel, "c":vehicleDistanceLabel]))
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[v]|", options: nil, metrics: [:], views: ["v":lineLabel]))
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[v]|", options: nil, metrics: [:], views: ["v":vehicleLabel]))
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[v]|", options: nil, metrics: [:], views: ["v":vehicleDistanceLabel]))
    
    // Increase font sizes of the labels
    let lineLabelFont = UIFont(descriptor: UIFontDescriptor.preferredDescriptorWithStyle(UIFontTextStyleHeadline, oversizedBy: 16), size: 0)
    lineLabel.font = lineLabelFont
    let vehicleLabelFont = UIFont(descriptor: UIFontDescriptor.defaultDescriptorWithStyle(UIFontTextStyleSubheadline, oversizedBy: 10), size: 0)
    vehicleLabel.font = vehicleLabelFont
    let vehicleDistanceLabelFont = UIFont(descriptor: UIFontDescriptor.defaultDescriptorWithStyle(UIFontTextStyleCaption1
      ), size: 0)
    vehicleDistanceLabel.font = vehicleDistanceLabelFont
    
    
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  required init(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }
  
  override func intrinsicContentSize() -> CGSize {
//    println("header vehicleDistanceLabel frame: \(vehicleDistanceLabel.frame)")
    return CGSize(width: VehicleHeaderView.defaultWidth + widthExtra, height: vehicleDistanceLabel.frame.maxY + 8)
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