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

typealias ApiControllerDelegateNextTask = (AnyObject?) -> Void

protocol APIControllerDelegate: class {

  func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?)
  func didReceiveError(urlerror: NSError, next: ApiControllerDelegateNextTask?)
}

struct Delegates {
  let vehicleDelegate, stopsDelegate, vehicleStopsDelegate: APIControllerDelegate
}

protocol APIControllerProtocol {
  
  static func sharedInstance() -> APIControllerProtocol
  
  func getVehicleActivitiesForLine(lineId: Int, next: ApiControllerDelegateNextTask?)
  func getVehicleActivityStopsForVehicle(vehicleRef: String, next: ApiControllerDelegateNextTask?)
  func getVehicleActivityHeaders(#next: ApiControllerDelegateNextTask?)
  func getStops(next: ApiControllerDelegateNextTask?)
  func connectedToNetwork() -> Bool
}

class APIController : APIControllerProtocol {
  
  private static var _sharedInstance = APIController()
  
  weak var vehicleDelegate, stopsDelegate, vehicleStopsDelegate: APIControllerDelegate?
  let journeysAPIbaseURL = "http://data.itsfactory.fi/journeys/api/1/"
  
  private init() {
    log.info("Created remote API controller using test data from folder '\(self.journeysAPIbaseURL)'")
  }
  
  static func sharedInstance() -> APIControllerProtocol {
    return _sharedInstance
  }
  
  func getVehicleActivitiesForLine(lineId: Int, next: ApiControllerDelegateNextTask?) {
    doGetOnPath("journeysAPIbaseURL?lineRef=\(lineId)", delegate: vehicleDelegate, next: next)
  }

//  func getVehicleActivities() {
//    doGetOnPath("journeysAPIbaseURL", delegate: vehDelegate, cachingEnabled: false)
//  }

  func getVehicleActivityStopsForVehicle(vehicleRef: String, next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity?vehicleRef=\(vehicleRef)", delegate: vehicleStopsDelegate, cachingEnabled: false, next: next)
  }

  func getVehicleActivityHeaders(#next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)vehicle-activity?exclude-fields=monitoredVehicleJourney.onwardCalls", delegate: vehicleDelegate, cachingEnabled: false, next: next)
  }

  func getStops(next: ApiControllerDelegateNextTask?) {
    doGetOnPath("\(journeysAPIbaseURL)stop-points", delegate: stopsDelegate, next: next)
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
  
  private func doGetOnPath(urlPath: String, delegate: APIControllerDelegate?, cachingEnabled: Bool = true, next: ApiControllerDelegateNextTask?) {
    if delegate == nil {
      log.error("Delegate not set!")
    }

    UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    let url = NSURL(string: urlPath)
    if let url = url {
      let request = NSMutableURLRequest(URL: url, cachePolicy: cachingEnabled ? .UseProtocolCachePolicy : .ReloadIgnoringLocalCacheData, timeoutInterval: 30.0)
      if cachingEnabled {
        if let cachedResponse = NSURLCache.sharedURLCache().cachedResponseForRequest(request) {
          log.debug("Using cached response for \(urlPath)")
          let json = JSON(data: cachedResponse.data)
          delegate?.didReceiveAPIResults(json, next: next)
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
          delegate?.didReceiveError(urlError, next: next)
          return
        } else {
          log.debug("Task completed successfully: " + urlPath)
          let json = JSON(data: data)
          delegate?.didReceiveAPIResults(json, next: next)
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
