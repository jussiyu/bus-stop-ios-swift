//
//  APIController.swift
//
//  Created by Jussi Yli-Urpo on 4.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import SwiftyJSON
import SystemConfiguration

protocol APIControllerProtocol {
  func didReceiveAPIResults(results: JSON)
  func didReceiveError(urlerror: NSError)
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

  func getVehicleActivities() {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/vehicle-activity", delegate: vehDelegate)
  }

  func getStops() {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/stop-points", delegate: stopsDelegate)
  }

  func connectedToNetwork() -> Bool {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    
    let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
      SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0)).takeRetainedValue()
    }
    
    var flags : SCNetworkReachabilityFlags = 0
    if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == 0 {
      return false
    }
    
    let isReachable = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
    let needsConnection = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
    return (isReachable && !needsConnection)
  }
  
  private func doGetOnPath(urlPath: String, delegate: APIControllerProtocol) {
    let url = NSURL(string: urlPath)
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    let task = NSURLSession.sharedSession().dataTaskWithURL(url!, completionHandler: {data, response, urlError -> Void in
      UIApplication.sharedApplication().networkActivityIndicatorVisible = false
      if(urlError != nil) {
        println("Task completed unsuccessfully: " + urlPath)
        println(urlError.localizedDescription)
        delegate.didReceiveError(urlError)
        return
      } else {
        println("Task completed successfully: " + urlPath)
        let json = JSON(data: data)
        delegate.didReceiveAPIResults(json)
      }
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
