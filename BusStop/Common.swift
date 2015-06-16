//
//  File.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 16.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
extension String {
  func toDouble() -> Double? {
    return NSNumberFormatter().numberFromString(self)?.doubleValue
  }
}

extension Double {
  func toString(#fractionDigits: Int) -> String? {
    let f = NSNumberFormatter()
    f.maximumFractionDigits = fractionDigits
    f.minimumFractionDigits = fractionDigits
    
    return f.stringFromNumber(self)
  }

}