//
//  File.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 16.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import UIKit
import XCGLogger
import CoreLocation

func cap<T : Comparable>(value: T, min minimum: T, max maximum: T) -> T {
  return max( min(maximum, value), minimum)
}

// MARK: - String
extension String {
  static let localeNumberFormatter: NSNumberFormatter = {
    let f = NSNumberFormatter()
    f.locale = NSLocale.currentLocale()
    f.numberStyle = NSNumberFormatterStyle.DecimalStyle
    return f
  }()

  static let posixNumberFormatter: NSNumberFormatter = {
    let f = NSNumberFormatter()
    f.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    f.numberStyle = NSNumberFormatterStyle.DecimalStyle
    return f
  }()

  static let iso8601DateFormatter: NSDateFormatter = {
    // 2015-07-13T14:32:00+03:00
    let f = NSDateFormatter()
    f.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    f.timeZone = NSTimeZone(forSecondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:sszzz"
    return f
  }()
  
  func toDouble() -> Double? {
    return String.localeNumberFormatter.numberFromString(self)?.doubleValue
  }
  func fromPOSIXStringToDouble() -> Double? {
    return String.posixNumberFormatter.numberFromString(self)?.doubleValue
  }
  
  func fromISO8601StringToDate() -> NSDate? {
    return String.iso8601DateFormatter.dateFromString(self)
  }

  func fromStringToTimeInterval() -> NSTimeInterval? {
      // -P0Y0M0DT0H3M20.000S",
    var interval: NSTimeInterval = 0
    let negative = self[self.startIndex] == "-"
    if let minutesRange = self.rangeOfString("H\\d+M", options: NSStringCompareOptions.RegularExpressionSearch) {
      var minutesString = self.substringWithRange(minutesRange)
      minutesString.removeAtIndex(minutesString.startIndex) // remove H
      minutesString.removeAtIndex(minutesString.endIndex.predecessor()) // remove M
      if let minutes = minutesString.toInt() {
        interval += NSTimeInterval(60 * minutes)
      }
    }
    if let secondsRange = self.rangeOfString("M\\d+\\.", options: NSStringCompareOptions.RegularExpressionSearch) {
      var secondsString = self.substringWithRange(secondsRange)
      secondsString.removeAtIndex(secondsString.startIndex) // remove M
      secondsString.removeAtIndex(secondsString.endIndex.predecessor()) // remove .
      if let seconds = secondsString.toInt() {
        interval += NSTimeInterval(seconds)
      }
    }
    
    return negative ? -interval : interval
  }

  var isBlank: Bool {
    get {
      let trimmed = stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
      return trimmed.isEmpty
    }
  }
  
}

// MARK: - Double
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
      return NSLocalizedString("***", comment: "double to string is unknown")
    }
    
  }

  func toInt(rounded: Bool = true) -> Int {
    
    return rounded ? Int(round(self)) : Int(self)
  }
}

// MARK: - NSObject
public extension NSObject{
  public class var nameOfClass: String{
    return NSStringFromClass(self).componentsSeparatedByString(".").last!
  }
  
  public var nameOfClass: String{
    return NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last!
  }
}

// MARK: - NSLayoutConstraint
extension NSLayoutConstraint {  
  class func constraintsWithVisualFormat(format: String, options opts: NSLayoutFormatOptions = nil, metrics: [String : AnyObject] = [:], views: [String : AnyObject] = [:], active: Bool) -> [NSLayoutConstraint] {
    let constraints = NSLayoutConstraint.constraintsWithVisualFormat(format, options: opts, metrics: metrics, views: views) as! [NSLayoutConstraint]
    if active {
      NSLayoutConstraint.activateConstraints(constraints)
    }
    return constraints
  }
}

// MARK: - UIView
extension UIView {
  func constraintsWithIdentifier(identifier: String) -> [NSLayoutConstraint] {
    var matching = [NSLayoutConstraint]()
    for c in constraints() {
      if let c = c as? NSLayoutConstraint {
        if c.identifier == identifier {
          matching.append(c)
        }
      }
    }
    return matching
  }
}

// MARK: - Array
extension Array{
  func each(each: (T) -> (T)) -> [T]{
    var result = [T]()
    for object: T in self {
      result.append(each(object))
    }
    return result
  }
  
  func indexOf<T : Equatable>(object:T) -> Int? {
    for (index,obj) in enumerate(self) {
      if obj as? T == object {
        return index
      }
    }
    return nil
  }

  mutating func remove<T : Equatable>(object:T) -> Int? {
    for (index,obj) in enumerate(self) {
      if obj as? T == object {
        self.removeAtIndex(index)
      }
    }
    return nil
  }
}

// MARK: - CLLocation
extension CLLocation {
  func moreAccurateThanLocation(other: CLLocation) -> Bool {
    return self.horizontalAccuracy < other.horizontalAccuracy
  }

  func commonHorizontalLocationWith (other: CLLocation) -> Bool {
    return self.coordinate.longitude == other.coordinate.longitude && self.coordinate.latitude == other.coordinate.latitude
  }
}

// MARK: - UITableView
extension UITableView {
  func scrollToTop(#animated: Bool) {
    // This is trigger didscroll messages
    self.setContentOffset(CGPoint(x: 0,y: 0), animated: true)
  }
}

// MARK: - Threading functions
func delay(delay:Double, closure:()->()) {
  
  dispatch_after(
    dispatch_time( DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), closure)
}

func synchronize<T>(lockObj: AnyObject!, closure: ()->T) -> T
{
  objc_sync_enter(lockObj)
  var retVal: T = closure()
  objc_sync_exit(lockObj)
  return retVal
}

func synchronize(lockObj: AnyObject!, closure: () -> ())
{
  objc_sync_enter(lockObj)
  closure()
  objc_sync_exit(lockObj)
}

var TICKTOCKStartTime = NSDate()
func TICK(){ TICKTOCKStartTime =  NSDate() }
func TOCK(function: String = __FUNCTION__, file: String = __FILE__, line: Int = __LINE__){
  log.debug("\(function) Time: \(TICKTOCKStartTime.timeIntervalSinceNow)\nLine:\(line) File: \(file)")
}

