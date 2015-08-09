//
//  BusStopHelpers.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 9.8.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import XCGLogger

let log = XCGLogger.defaultInstance()

func setUpLog() {
  log.setup(logLevel: .Verbose, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: .None)
  let shortLogDateFormatter = NSDateFormatter()
  shortLogDateFormatter.locale = NSLocale.currentLocale()
  shortLogDateFormatter.dateFormat = "HH:mm:ss.SSS"
  log.dateFormatter = shortLogDateFormatter
  log.xcodeColorsEnabled = true
  log.xcodeColors[XCGLogger.LogLevel.Info] = XCGLogger.XcodeColor(fg: (147, 147, 255))
}
