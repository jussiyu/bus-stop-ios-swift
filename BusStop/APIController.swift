//
//  APIController.swift
//
//  Created by Jussi Yli-Urpo on 4.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import SwiftyJSON

protocol APIControllerProtocol {
  func didReceiveAPIResults(results: JSON)
}

class APIController {
  let vehDelegate, stopsDelegate: APIControllerProtocol
  
  init(vehDelegate: APIControllerProtocol, stopsDelegate: APIControllerProtocol) {
    self.vehDelegate = vehDelegate
    self.stopsDelegate = stopsDelegate
  }
  
  func getVehicleActivitiesForLine(lineId: Int) {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/vehicle-activity?lineRef=\(lineId)", delegate: vehDelegate)
  }

  func getStops() {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/stop-points", delegate: stopsDelegate)
  }

  //    if(!vehicleId.isBlank) {
//      if let escapedVehicleRef = vehicleId.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
//        urlPath += "&vehicleRef=\(escapedVehicleRef)"
//      }
//    }

  private func doGetOnPath(urlPath: String, delegate: APIControllerProtocol) {
    let url = NSURL(string: urlPath)
    let session = NSURLSession.sharedSession()
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    let task = session.dataTaskWithURL(url!, completionHandler: {data, response, urlError -> Void in
      UIApplication.sharedApplication().networkActivityIndicatorVisible = false
      if(urlError != nil) {
        // If there is an error in the web request, print it to the console
        println("Task completed unsuccessfully: " + urlPath)
        println(urlError.localizedDescription)
        return
      } else {
        println("Task completed successfully: " + urlPath)
      }
      let json = JSON(data: data)
      delegate.didReceiveAPIResults(json)
    })
    
    // The task is just an object with all these properties set
    // In order to actually make the web request, we need to "resume"
    task.resume()
  }
}

extension String {
  
  var isBlank: Bool {
    get {
      let trimmed = stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
      return trimmed.isEmpty
    }
  }
  
}
