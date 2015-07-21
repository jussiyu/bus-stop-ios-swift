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


protocol APIControllerProtocol {

  func didReceiveAPIResults(results: JSON, next: APIController.NextTask?)
  func didReceiveError(urlerror: NSError, next: APIController.NextTask?)
}

class APIController {
  typealias NextTask = (AnyObject?) -> Void

  let vehDelegate, stopsDelegate, vehStopsDelegate: APIControllerProtocol
  
  init(vehDelegate: APIControllerProtocol, stopsDelegate: APIControllerProtocol, vehStopsDelegate: APIControllerProtocol) {
    self.vehDelegate = vehDelegate
    self.stopsDelegate = stopsDelegate
    self.vehStopsDelegate = vehStopsDelegate
  }
  
  func getVehicleActivitiesForLine(lineId: Int, next: NextTask?) {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/vehicle-activity?lineRef=\(lineId)", delegate: vehDelegate, next: next)
  }

//  func getVehicleActivities() {
//    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/vehicle-activity", delegate: vehDelegate, cachingEnabled: false)
//  }

  func getVehicleActivityStopsForVehicle(vehicleRef: String, next: NextTask?) {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/vehicle-activity?vehRef=\(vehicleRef)", delegate: vehStopsDelegate, cachingEnabled: false, next: next)
  }

  func getVehicleActivityHeaders(#next: NextTask?) {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/vehicle-activity?exclude-fields=monitoredVehicleJourney.onwardCalls", delegate: vehDelegate, cachingEnabled: false, next: next)
  }

  func getStops(next: NextTask?) {
    doGetOnPath("http://data.itsfactory.fi/journeys/api/1/stop-points", delegate: stopsDelegate, next: next)
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
  
  private func doGetOnPath(urlPath: String, delegate: APIControllerProtocol, cachingEnabled: Bool = true, next: NextTask?) {
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    let url = NSURL(string: urlPath)
    if let url = url {
      let request = NSMutableURLRequest(URL: url, cachePolicy: cachingEnabled ? .UseProtocolCachePolicy : .ReloadIgnoringLocalCacheData, timeoutInterval: 30.0)
      if cachingEnabled {
        if let cachedResponse = NSURLCache.sharedURLCache().cachedResponseForRequest(request) {
          log.debug("Using cached response for \(urlPath)")
          let json = JSON(data: cachedResponse.data)
          delegate.didReceiveAPIResults(json, next: next)
          return
        }
      } else {
        if let cachedResponse = NSURLCache.sharedURLCache().cachedResponseForRequest(request) {
          log.warning("Cached response exists for \(urlPath). Removed!")
          NSURLCache.sharedURLCache().removeCachedResponseForRequest(request)
        }
      }
      var configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
      if !cachingEnabled {
        configuration.URLCache = nil
        configuration.requestCachePolicy = .ReloadIgnoringLocalCacheData
        request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
      }
      
      let task = NSURLSession(configuration: configuration).dataTaskWithURL(url, completionHandler: {data, response, urlError -> Void in
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        if(urlError != nil) {
          log.error("Task completed unsuccessfully: " + urlPath)
          log.error(urlError.localizedDescription)
          delegate.didReceiveError(urlError, next: next)
          return
        } else {
          log.debug("Task completed successfully: " + urlPath)
          let json = JSON(data: data)
          delegate.didReceiveAPIResults(json, next: next)
        }
      })
      
      // The task is just an object with all these properties set
      // In order to actually make the web request, we need to "resume"
      task.resume()
    } else {
      log.severe("Invalid URL: " + urlPath)
    }
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