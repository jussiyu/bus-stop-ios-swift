//
//  APIControllerLocal.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 29.7.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

//
//  APIController.swift
//
//  Created by Jussi Yli-Urpo on 4.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import SwiftyJSON
import SystemConfiguration
import XCGLogger
import TaskQueue


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
  
  //  func getVehicleActivities() {
  //    doGetOnPath("journeysAPIbaseURL", delegate: vehDelegate, cachingEnabled: false)
  //  }
  
  func getVehicleActivityStopsForVehicle(vehicleRef: String, next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity", delegate: vehicleStopsDelegate, cachingEnabled: false, next: next)
  }
  
  func getVehicleActivityHeaders(#next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity", delegate: vehicleDelegate, cachingEnabled: false, next: next)
  }
  
  func getStops(next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)stop-points", delegate: stopsDelegate, next: next)
  }
  
  func connectedToNetwork() -> Bool {
    return true
  }
  
  private func doGetOnPath(filePath: String, delegate: APIControllerDelegate?, cachingEnabled: Bool = true, next: ApiControllerDelegateNextTask?) {
    if delegate == nil {
      log.error("Delegate not set!")
    }
    
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    if let path = NSBundle.mainBundle().pathForResource(filePath, ofType: journeysAPIDataFormat) {
      var error: NSError?
      if let data = NSData(contentsOfFile: path, options: NSDataReadingOptions.DataReadingMappedIfSafe, error: &error) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        log.debug("Local data loaded completed successfully: \(filePath).\(self.journeysAPIDataFormat)")
        let json = JSON(data: data)
        if let jsonError = json.error {
          log.error("Error parsing JSON: \(jsonError)")
        } else {
          delegate?.didReceiveAPIResults(json, next: next)
        }
      } else {
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
