//
//  VehicleHeaderView.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 13.7.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit
import XCGLogger

class VehicleHeaderView: UIView {
  
  var lineLabel: UILabel!
  var vehicleLabel: UILabel!
  var vehicleDistanceLabel: UILabel!
  
  var lineLabelHeightConstraint: NSLayoutConstraint?
  var vehicleDistanceLabelHeightConstraint: NSLayoutConstraint?
  
  static let defaultWidth: CGFloat = 200
  var widthExtra: CGFloat = 0
  
  convenience init(lineRef: String, vehicleRef: String, distance: String) {
    var frame = CGRectZero
    self.init(frame: frame)
    self.setContentHuggingPriority(0, forAxis: .Horizontal)

//    backgroundColor = UIColor.lightGrayColor()
    lineLabel = UILabel()
    lineLabel.textAlignment = NSTextAlignment.Center
    lineLabel.text = lineRef
//    lineLabel.backgroundColor = UIColor.yellowColor()
    vehicleLabel = UILabel()
    vehicleLabel.textAlignment = NSTextAlignment.Center
    vehicleLabel.text = vehicleRef
//    vehicleLabel.backgroundColor = UIColor.redColor()
    vehicleLabel.setContentHuggingPriority(1000, forAxis: .Vertical)
    vehicleDistanceLabel = UILabel()
    vehicleDistanceLabel.textAlignment = NSTextAlignment.Center
    vehicleDistanceLabel.text = distance.stringByReplacingOccurrencesOfString("\\n", withString: "\n", options: nil)
    vehicleDistanceLabel.numberOfLines = 2
    vehicleDistanceLabel.setContentHuggingPriority(1000, forAxis: .Vertical)
//    vehicleDistanceLabel.backgroundColor = UIColor.greenColor()
    
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
    log.verbose("header vehicleDistanceLabel frame: \(self.vehicleDistanceLabel.frame)")
    return CGSize(width: VehicleHeaderView.defaultWidth + widthExtra, height: vehicleDistanceLabel.frame.maxY + 8)
  }
  
  func fadeOutByOffset(offset: CGFloat) {
    var amount = min(1, 1 - (bounds.height - offset) / bounds.height)
    amount = amount < 0.01 ? 0 : amount
    
    minimizeView(lineLabel, constraint: &lineLabelHeightConstraint, byAmount: amount)
    minimizeView(vehicleDistanceLabel, constraint: &vehicleDistanceLabelHeightConstraint, byAmount: amount)
    
    layoutIfNeeded()
  }
  
  private func minimizeView(view: UIView, inout constraint: NSLayoutConstraint?, byAmount: CGFloat) {
    log.verbose("shink amount: \(byAmount * 100)%, constraint.constant: \(constraint?.constant)")
    
    view.alpha =  max(0, 1 - byAmount*4)

    // store intrinsic height
    let intrinsicHeight = view.intrinsicContentSize().height
    
    // initialize constraint with intrinsic height constant if not done already
    if constraint == nil {
      constraint = NSLayoutConstraint.constraintsWithVisualFormat("V:[v(intrinsic@250)]", metrics: ["intrinsic":intrinsicHeight], views: ["v":view], active: false).first
      constraint?.active = true
    }
    
    // activate, set current constant based on offset and increase priority
    constraint?.constant = intrinsicHeight * (1 - byAmount)
    constraint?.priority = byAmount > 0 ? 999 : 250
    
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