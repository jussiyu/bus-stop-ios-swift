// Copyright (c) 2015 Solipaste Oy
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation


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
      if let minutes = Int(minutesString) {
        interval += NSTimeInterval(60 * minutes)
      }
    }
    if let secondsRange = self.rangeOfString("M\\d+\\.", options: NSStringCompareOptions.RegularExpressionSearch) {
      var secondsString = self.substringWithRange(secondsRange)
      secondsString.removeAtIndex(secondsString.startIndex) // remove M
      secondsString.removeAtIndex(secondsString.endIndex.predecessor()) // remove .
      if let seconds = Int(secondsString) {
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

// MARK: - Int
extension Int {
  static func random(min: Int, max: Int) -> Int {
    let range = UInt32(max - min)
    let rndInt = Int(arc4random_uniform(range + 1)) + min
    return rndInt
  }
  
  static func random(max: Int) -> Int {
    let rnd = Int(arc4random_uniform(UInt32(max) + 1))
    return rnd
  }
}

// MARK: - Double
extension Double {
  static var f: NSNumberFormatter = {
    let f = NSNumberFormatter()
    f.numberStyle = NSNumberFormatterStyle.DecimalStyle
    return f
    }()
  
  func toString(fractionDigits fractionDigits: Int) -> String {
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


// MARK: - Array
extension Array{
  func each(each: (Element) -> (Element)) -> [Element]{
    var result = [Element]()
    for object: Element in self {
      result.append(each(object))
    }
    return result
  }
  
  func indexOf<T : Equatable>(object:T) -> Int? {
    for (index,obj) in self.enumerate() {
      if obj as? T == object {
        return index
      }
    }
    return nil
  }
  
  mutating func remove<T : Equatable>(object:T) -> Int? {
    for (index,obj) in self.enumerate() {
      if obj as? T == object {
        self.removeAtIndex(index)
      }
    }
    return nil
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
  let retVal: T = closure()
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

