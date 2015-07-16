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
  
  var vehicleTopOffsetConstraint: NSLayoutConstraint!
  var vehicleTopOffsetConstant: NSNumber = 0
  var vehicleTopOffsetConstantDefault: CGFloat?
  
  static let defaultWidth: CGFloat = 200
  var widthExtra: CGFloat = 0
  
  convenience init(lineRef: String, vehicleRef: String, distance: String) {
    var frame = CGRectZero
    self.init(frame: frame)
    self.setContentHuggingPriority(0, forAxis: .Horizontal)

    backgroundColor = UIColor.lightGrayColor()
    lineLabel = UILabel()
    lineLabel.textAlignment = NSTextAlignment.Center
    lineLabel.text = lineRef
    vehicleLabel = UILabel()
    vehicleLabel.textAlignment = NSTextAlignment.Center
    vehicleLabel.text = vehicleRef
    vehicleLabel.backgroundColor = UIColor.redColor()
    vehicleLabel.setContentHuggingPriority(1000, forAxis: .Vertical)
    vehicleDistanceLabel = UILabel()
    vehicleDistanceLabel.textAlignment = NSTextAlignment.Center
    vehicleDistanceLabel.text = distance.stringByReplacingOccurrencesOfString("\\n", withString: "\n", options: nil)
    vehicleDistanceLabel.numberOfLines = 2
    vehicleDistanceLabel.setContentHuggingPriority(1000, forAxis: .Vertical)
    vehicleDistanceLabel.backgroundColor = UIColor.greenColor()
    
    // add child views
    addSubview(lineLabel)
    addSubview(vehicleLabel)
    addSubview(vehicleDistanceLabel)

    // Constraints
    lineLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
    vehicleLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
    vehicleDistanceLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(8@750)-[a]-(8@750)-[b]-(8@1000)-[c]-(8@1000)-|", options: nil, metrics: [:], views: ["a":lineLabel, "b":vehicleLabel, "c":vehicleDistanceLabel]))

    //    vehicleTopOffsetConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.Top, relatedBy: .Equal, toItem: vehicleLabel, attribute: .Top, multiplier: 1, constant: 0)
    //    vehicleTopOffsetConstraint.priority = 250
    vehicleTopOffsetConstraint = NSLayoutConstraint.constraintsWithVisualFormat("V:|-(offset@250)-[v]", options: nil, metrics: ["offset":vehicleTopOffsetConstant], views: ["v":vehicleLabel]).first as! NSLayoutConstraint
    
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[v]|", options: nil, metrics: [:], views: ["v":lineLabel]))
    NSLayoutConstraint.activateConstraints([vehicleTopOffsetConstraint])
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
  
  func fadeOutByOffset(offset:CGFloat) {
    let scaledOffset = Float((bounds.height - offset) / bounds.height)
//    lineLabel.alpha =  scaledOffset * 0.7
//    lineLabel.transform = CGAffineTransformMakeScale(1, scaledOffset)
    vehicleTopOffsetConstantDefault = vehicleTopOffsetConstantDefault ?? vehicleLabel.frame.minY
    vehicleTopOffsetConstraint.constant = max(0, vehicleTopOffsetConstantDefault! - offset * 10)
    vehicleTopOffsetConstraint.priority = offset > 0 ? 999 : 250
    vehicleDistanceLabel.alpha = (bounds.height - offset) / bounds.height * 0.7
    println("scaledOffset: \(scaledOffset), vehicleTopOffsetConstraint.constant: \(vehicleTopOffsetConstraint.constant)")
//    vehicleDistanceLabel.transform = CGAffineTransformMakeScale(1, scaledOffset)
    invalidateIntrinsicContentSize()
    layoutIfNeeded()
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