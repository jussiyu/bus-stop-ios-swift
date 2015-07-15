//
//  File.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 16.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import UIKit

extension String {
  static var f: NSNumberFormatter = {
    let f = NSNumberFormatter()
    f.numberStyle = NSNumberFormatterStyle.DecimalStyle
    return f
  }()
  
  func toDouble() -> Double? {
    String.f.locale = NSLocale.currentLocale()
    return String.f.numberFromString(self)?.doubleValue
  }
  func fromPOSIXStringtoDouble() -> Double? {
    String.f.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    return String.f.numberFromString(self)?.doubleValue
  }
  
  func localizedWithComment(comment:String) -> String {
    return NSLocalizedString(self, tableName: nil, bundle: NSBundle.mainBundle(), value: "", comment: comment)
  }

  func localized() -> String {
    return NSLocalizedString(self, tableName: nil, bundle: NSBundle.mainBundle(), value: "", comment: self)
  }
}

extension Double {
  static var f: NSNumberFormatter = {
    let f = NSNumberFormatter()
    f.numberStyle = NSNumberFormatterStyle.DecimalStyle
    return f
  }()
  
  func toString(#fractionDigits: Int) -> String {
    Double.f.maximumFractionDigits = fractionDigits
    Double.f.minimumFractionDigits = fractionDigits
    if let s = Double.f.stringFromNumber(self) {
      return s
    } else {
      return "***".localizedWithComment("double to string is unknown")
    }
    
  }

  func toInt(rounded: Bool = true) -> Int {
    return rounded ? Int(round(self)) : Int(self)
  }
}

func delay(delay:Double, closure:()->()) {
  
  dispatch_after(
    dispatch_time( DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), closure)
  
  
}

public extension NSObject{
  public class var nameOfClass: String{
    return NSStringFromClass(self).componentsSeparatedByString(".").last!
  }
  
  public var nameOfClass: String{
    return NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last!
  }
}

extension NSLayoutConstraint {
  class var standardAquaSpaceConstraintFromItem: CGFloat {
    struct Holder {
      static var standardConstantBetweenSiblings: CGFloat?
    }
    if Holder.standardConstantBetweenSiblings == nil {
      let view = UIView()
      let constraintWithStandardConstantBetweenSiblings = NSLayoutConstraint.constraintsWithVisualFormat("[view]-[view]", options:nil, metrics: [:], views: ["view": view]).first as! NSLayoutConstraint
      Holder.standardConstantBetweenSiblings = constraintWithStandardConstantBetweenSiblings.constant     // 8.0
    }
    return Holder.standardConstantBetweenSiblings!
  }
  
  static var standardConstantBetweenSuperview: CGFloat {
    struct Holder {
      static var standardConstantBetweenSuperview: CGFloat?
    }
    if Holder.standardConstantBetweenSuperview == nil {
      let superview = UIView()
      let subView = UIView()
      superview.addSubview(subView)
      let constraintWithStandardConstantBetweenSuperview = NSLayoutConstraint.constraintsWithVisualFormat("[view]-|",  options:nil, metrics:[:], views: ["view": subView]).first as! NSLayoutConstraint
      Holder.standardConstantBetweenSuperview = constraintWithStandardConstantBetweenSuperview.constant    // 20.0
    }
    return Holder.standardConstantBetweenSuperview!
  }
}