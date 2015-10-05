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
import SwiftyJSON
import SystemConfiguration
import XCGLogger
import TaskQueue


//
// MARK: - APIControllerProtocol implementation
//
class APIControllerLocal : APIControllerProtocol {
  
  private static var _sharedInstance = APIControllerLocal()

  weak var vehicleDelegate, stopsDelegate, vehicleStopsDelegate: APIControllerDelegate?
  let journeysAPIbaseURL = "testdata/"
  let journeysAPIDataFormat = "json"
  
  private init() {
    log.info("!!! Created local API controller using test data from folder '\(self.journeysAPIbaseURL)' !!!")
  }
  
  static func sharedInstance() -> APIControllerProtocol {
    return _sharedInstance
  }
  
  func invalidateSessions() {}

  func getVehicleActivitiesForLine(lineId: Int, next: ApiControllerDelegateNextTask?) {
    doGetOnPath("journeysAPIbaseURL?lineRef", delegate: vehicleDelegate, next: next)
  }
  
 
  func getVehicleActivityStopsForVehicle(vehicleRef: String, next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity", delegate: vehicleStopsDelegate, cachingEnabled: false, next: next)
  }
  
  func getVehicleActivityHeaders(next next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity", delegate: vehicleDelegate, cachingEnabled: false, next: next)
  }
  
  func getStops(next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)stop-points", delegate: stopsDelegate, next: next)
  }
  
  func connectedToNetwork() -> Bool {
    return true
  }
  
  func cancelTasks() {
    //noop
  }
  
  private func doGetOnPath(filePath: String, delegate: APIControllerDelegate?, cachingEnabled: Bool = true, next: ApiControllerDelegateNextTask?) {
    if delegate == nil {
      log.error("Delegate not set!")
    }
    
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    if let path = NSBundle.mainBundle().pathForResource(filePath, ofType: journeysAPIDataFormat) {
      var error: NSError?
      do {
        let data = try NSData(contentsOfFile: path, options: NSDataReadingOptions.DataReadingMappedIfSafe)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        log.debug("Local data loaded completed successfully: \(filePath).\(self.journeysAPIDataFormat)")
        let json = JSON(data: data)
        if let jsonError = json.error {
          log.error("Error parsing JSON: \(jsonError)")
        } else {
          delegate?.didReceiveAPIResults(json, next: next)
        }
      } catch var error1 as NSError {
        error = error1
        if let error = error {
          log.error("Local data loaded unsuccessfully: \(filePath).\(self.journeysAPIDataFormat)")
          log.error(error.localizedDescription)
          delegate?.didReceiveError(error, next: next)
        }
        return
      }
    } else {
      log.error("Invalid path: \(filePath)")
    }
  }
}
