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
import XCGLogger
import RealmSwift

let log = XCGLogger.defaultInstance()

func setUpLog() {
  log.setup(.Verbose, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: .None)
  let shortLogDateFormatter = NSDateFormatter()
  shortLogDateFormatter.locale = NSLocale.currentLocale()
  shortLogDateFormatter.dateFormat = "HH:mm:ss.SSS"
  log.dateFormatter = shortLogDateFormatter
  log.xcodeColorsEnabled = false
  log.xcodeColors[XCGLogger.LogLevel.Info] = XCGLogger.XcodeColor(fg: (147, 147, 255))
}

func setUpDatabase() {
  let fileManager = NSFileManager.defaultManager()
  do {
    let documentPathURL = try fileManager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: NSURL?(), create: true)
    let path = documentPathURL.URLByAppendingPathComponent("unittest.realm").path
    Realm.Configuration.defaultConfiguration = Realm.Configuration(path: path)
    log.info("Realm default database path set to \(Realm.Configuration.defaultConfiguration.path)")
  } catch let error as NSError {
    log.info("Failed initialize Realm default database path: \(error)")
  }
}

func deleteAllDatabaseData() {
  let databasePath = Realm.Configuration.defaultConfiguration.path
  do {
    let checkValidation = NSFileManager.defaultManager()
    if let databasePath = databasePath where checkValidation.fileExistsAtPath(databasePath) {
      try Realm().write {
        do {
          try Realm().deleteAll()
        } catch let error as NSError {
          log.error("failed to delete all DB data: \(error)")
        }
      }
    } else {
      log.info("database does not exist. ignoring.")
    }
  } catch let error as NSError {
    log.info("failed perform database write: \(error)")
  }
}

