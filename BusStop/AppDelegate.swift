//
//  AppDelegate.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 5.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit
import CoreLocation
import ReachabilitySwift
import XCGLogger

let log = XCGLogger.defaultInstance()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  var lm: CLLocationManager?

  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    // Override point for customization after application launch.
    let locStatus = CLLocationManager.authorizationStatus()
    log.debug("location auth status: \(locStatus.hashValue)")
    switch locStatus {
    case CLAuthorizationStatus.AuthorizedAlways:
      initLocation(locStatus)
    case CLAuthorizationStatus.AuthorizedWhenInUse:
      initLocation(locStatus)
    case CLAuthorizationStatus.NotDetermined:
      initLocation(locStatus)
    default:
      log.error("location auth failed: \(locStatus.hashValue)")
    }

    // Logger configuration
    #if DEBUG
      log.setup(logLevel: .Verbose, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: .None)
      let shortLogDateFormatter = NSDateFormatter()
      shortLogDateFormatter.locale = NSLocale.currentLocale()
      shortLogDateFormatter.dateFormat = "HH:mm:ss.SSS"
      log.dateFormatter = shortLogDateFormatter
      log.xcodeColorsEnabled = true
      log.xcodeColors[XCGLogger.LogLevel.Info] = XCGLogger.XcodeColor(fg: (147, 147, 255))
    #else
      log.setup(logLevel: .Severe, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: .None)
    #endif
    
//    // URL cache
//    let URLCache = NSURLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 4 * 1024 * 1024, diskPath: "nsurlcache")
//    NSURLCache.setSharedURLCache(URLCache)
    
    return true
  }

  func applicationWillResignActive(application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    lm?.stopUpdatingLocation()
  }

  func applicationWillEnterForeground(application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    lm?.requestWhenInUseAuthorization()
    if CLLocationManager.locationServicesEnabled() {
      lm?.startUpdatingLocation()
      log.debug("start location monitoring")
    } else {
      log.debug("location monitoring disabled")
    }
  }

  func applicationDidBecomeActive(application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
  
  func applicationDidReceiveMemoryWarning(application: UIApplication) {
    // Clean URL caches
    NSURLCache.sharedURLCache().removeAllCachedResponses()
  }

  func initLocation(status: CLAuthorizationStatus) {
    lm = CLLocationManager()
    lm?.delegate = self
    lm?.desiredAccuracy = kCLLocationAccuracyBest
    lm?.activityType = CLActivityType.Other
    lm?.distanceFilter = 10 // meters
    switch status {
    case CLAuthorizationStatus.AuthorizedAlways:
      lm?.startUpdatingLocation()
    case CLAuthorizationStatus.AuthorizedWhenInUse:
      lm?.startUpdatingLocation()
    case CLAuthorizationStatus.NotDetermined:
      lm?.requestWhenInUseAuthorization()
    default:
      log.warning("Location service not allowed")
    }

  }

}

extension AppDelegate: CLLocationManagerDelegate {
  func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
    log.debug("didUpdateLocations: \(locations[0].description)")
    if let latestLoc = locations.last as? CLLocation {
      if latestLoc.horizontalAccuracy > 0 && latestLoc.timestamp.timeIntervalSinceNow > -30 {
        // good enough location received
        NSNotificationCenter.defaultCenter().postNotificationName("newLocationNotif", object: self, userInfo: ["newLocationResult": locations[0]])
        lm?.stopUpdatingLocation()
      }
    }
  }
  
  func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
    log.error("Location Manager didFailWithError: \(error)")
    if error == CLError.Denied.rawValue || error == CLError.LocationUnknown.rawValue {
      lm?.stopUpdatingLocation()
    }
  }
  
  func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
    log.debug("didChangeAuthorizationStatus: \(status.hashValue)")
    switch status {
    case CLAuthorizationStatus.AuthorizedAlways:
      lm?.startUpdatingLocation()
    case CLAuthorizationStatus.AuthorizedWhenInUse:
      lm?.startUpdatingLocation()
    default:
      log.error("Location service not allowed")
    }
  }
}
