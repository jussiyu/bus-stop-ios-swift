//
//  APIController.swift
//
//  Created by Jussi Yli-Urpo on 4.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Common
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
  func invalidateSessions()
  func cancelTasks()
}

class APIController : NSObject, APIControllerProtocol {
  
  private static var _sharedInstance = APIController()
  lazy var defaultSession: NSURLSession = {
    var defaultConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
    return NSURLSession(configuration: defaultConfiguration, delegate: self, delegateQueue: nil)
  }()
  lazy var cachedSession: NSURLSession  = {
    var cachedConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
    cachedConfiguration.URLCache = nil
    cachedConfiguration.requestCachePolicy = .ReloadIgnoringLocalCacheData
    return NSURLSession(configuration: cachedConfiguration)
  }()
  
  weak var vehicleDelegate, stopsDelegate, vehicleStopsDelegate: APIControllerDelegate?
  let journeysAPIbaseURL = "http://data.itsfactory.fi/journeys/api/1/"
  
  /// Tasks that are either .Suspended, .Running or .Cancelling
  var activeTasks = [NSURLSessionDataTask]()
  
  override private init() {
    super.init()
    log.info("Created remote API controller using test data from folder '\(self.journeysAPIbaseURL)'")
  }
  
  deinit {
    invalidateSessions()
  }
  
  /// Cancel all active tasks
  func cancelTasks() {
    log.verbose("")
    synchronize(activeTasks) {
      while !self.activeTasks.isEmpty {
        self.activeTasks.removeLast().cancel()
      }
    }
  }
  
  static func sharedInstance() -> APIControllerProtocol {
    return _sharedInstance
  }

  func invalidateSessions() {
    log.verbose("")
    defaultSession.invalidateAndCancel()
    cachedSession.invalidateAndCancel()
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
        request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
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

      let session = cachingEnabled ? cachedSession : defaultSession
      
      let task = session.dataTaskWithURL(url, completionHandler: {data, response, error -> Void in
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        if let response = response as? NSHTTPURLResponse where error == nil && response.statusCode == 200 {
          log.debug("Task completed successfully: " + urlPath)
          let json = JSON(data: data)
          delegate?.didReceiveAPIResults(json, next: next)
        } else {
          log.error("Task completed unsuccessfully: " + urlPath)
          log.error(error.localizedDescription)
          delegate?.didReceiveError(error, next: next)
          return
        }
      })
      
      task.resume()
      synchronize(activeTasks) {
        if task.state == .Running {
          self.activeTasks.append(task)
        }
      }
      log.debug("Started datatask with id \(task.taskIdentifier))")
    } else {
      log.severe("Invalid URL: " + urlPath)
    }
  }
}

extension APIController: NSURLSessionDataDelegate {
  func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
    log.debug("didCompleteWithError: \(task.taskIdentifier)")
    synchronize(activeTasks) {
      self.activeTasks.remove(task)
    }
  }
}