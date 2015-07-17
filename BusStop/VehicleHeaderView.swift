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
//    println("header vehicleDistanceLabel frame: \(vehicleDistanceLabel.frame)")
    return CGSize(width: VehicleHeaderView.defaultWidth + widthExtra, height: vehicleDistanceLabel.frame.maxY + 8)
  }
  
  func fadeOutByOffset(offset: CGFloat) {
    var amount = min(1, 1 - (bounds.height - offset) / bounds.height)
    amount = amount < 0.01 ? 0 : amount
    
    shrinkView(lineLabel, constraint: &lineLabelHeightConstraint, byAmount: amount)
    shrinkView(vehicleDistanceLabel, constraint: &vehicleDistanceLabelHeightConstraint, byAmount: amount)
    
//    lineLabel.transform = CGAffineTransformMakeScale(1, scaledOffset)
//    vehicleDistanceLabel.alpha = (bounds.height - offset) / bounds.height * 0.7
//    invalidateIntrinsicContentSize()
    layoutIfNeeded()
  }
  
  private func shrinkView(view: UIView, inout constraint: NSLayoutConstraint?, byAmount: CGFloat) {
    println("shink amount: \(byAmount * 100)%, constraint.constant: \(constraint?.constant)")
    
    view.alpha =  1 - byAmount * 2

    // store intrinsic height
    let intrinsicHeight = view.intrinsicContentSize().height
    
    // initialize constraint with intrinsic height constant if not done already
    if constraint == nil {
      constraint = NSLayoutConstraint.constraintsWithVisualFormatForSwift("V:[v(intrinsic@250)]", metrics: ["intrinsic":intrinsicHeight], views: ["v":view]).first
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