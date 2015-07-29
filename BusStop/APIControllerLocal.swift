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
  
  let vehDelegate, stopsDelegate, vehStopsDelegate: APIControllerDelegate
  let journeysAPIbaseURL = "testdata/"
  let journeysAPIDataFormat = "json"
  
  init(vehDelegate: APIControllerDelegate, stopsDelegate: APIControllerDelegate, vehStopsDelegate: APIControllerDelegate) {
    self.vehDelegate = vehDelegate
    self.stopsDelegate = stopsDelegate
    self.vehStopsDelegate = vehStopsDelegate
    
    log.info("!!! Using test data from folder '\(self.journeysAPIbaseURL)' !!!")
  }
  
  func getVehicleActivitiesForLine(lineId: Int, next: ApiControllerDelegateNextTask?) {
    doGetOnPath("journeysAPIbaseURL?lineRef", delegate: vehDelegate, next: next)
  }
  
  //  func getVehicleActivities() {
  //    doGetOnPath("journeysAPIbaseURL", delegate: vehDelegate, cachingEnabled: false)
  //  }
  
  func getVehicleActivityStopsForVehicle(vehicleRef: String, next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity", delegate: vehStopsDelegate, cachingEnabled: false, next: next)
  }
  
  func getVehicleActivityHeaders(#next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity", delegate: vehDelegate, cachingEnabled: false, next: next)
  }
  
  func getStops(next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)stop-points", delegate: stopsDelegate, next: next)
  }
  
  func connectedToNetwork() -> Bool {
    return true
  }
  
  private func doGetOnPath(filePath: String, delegate: APIControllerDelegate, cachingEnabled: Bool = true, next: ApiControllerDelegateNextTask?) {
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    if let path = NSBundle.mainBundle().pathForResource(filePath, ofType: journeysAPIDataFormat) {
      var error: NSError?
      if let data = NSData(contentsOfFile: path, options: NSDataReadingOptions.DataReadingMappedIfSafe, error: &error) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        log.debug("Local data loaded completed successfully: \(filePath).\(self.journeysAPIDataFormat)")
        let json = JSON(data: data)
        delegate.didReceiveAPIResults(json, next: next)
      } else {
        if let error = error {
          log.error("Local data loaded unsuccessfully: \(filePath).\(self.journeysAPIDataFormat)")
          log.error(error.localizedDescription)
          delegate.didReceiveError(error, next: next)
        }
        return
      }
    } else {
      log.error("Invalid path: \(filePath)")
    }
  }
}
