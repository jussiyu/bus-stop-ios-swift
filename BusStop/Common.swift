//
//  File.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 16.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
extension String {
  static var f: NSNumberFormatter {
    let f = NSNumberFormatter()
    f.numberStyle = NSNumberFormatterStyle.DecimalStyle
    return f
  }

  func toDouble() -> Double? {
    String.f.locale = NSLocale.currentLocale()
    return String.f.numberFromString(self)?.doubleValue
  }
  func fromPOSIXStringtoDouble() -> Double? {
    String.f.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    return String.f.numberFromString(self)?.doubleValue
  }
}

extension Double {
  static var f: NSNumberFormatter {
    let f = NSNumberFormatter()
    f.numberStyle = NSNumberFormatterStyle.DecimalStyle
    return f
  }
  
  func toString(#fractionDigits: Int) -> String? {
    Double.f.maximumFractionDigits = fractionDigits
    Double.f.minimumFractionDigits = fractionDigits
    
    return Double.f.stringFromNumber(self)
  }

}