
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

  static let newLocationNotificationName = "newLocationNotification"
  static let newLocationResult = "newLocationResult"
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    
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

    if let launchOptions = launchOptions,
      localNotification = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
      log.debug("local notification received: \(localNotification)")
    } else {
      UIApplication.sharedApplication().cancelAllLocalNotifications()
      let localNotification = UILocalNotification()
      localNotification.fireDate = NSDate(timeIntervalSinceNow: 60)
      localNotification.alertAction = nil
      localNotification.soundName = UILocalNotificationDefaultSoundName
      localNotification.alertBody = "Testing local notification"
      localNotification.alertAction = NSLocalizedString("Action", comment:"")
      localNotification.applicationIconBadgeNumber = 1
      localNotification.repeatInterval = nil
      UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
    }
    
    // reset badge if allowed
    if UIApplication.sharedApplication().currentUserNotificationSettings().types & UIUserNotificationType.Badge != nil {
      UIApplication.sharedApplication().applicationIconBadgeNumber = 0
    }

    // Request local notification usage
    UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Badge | .Alert | .Sound, categories: nil))

    if CLLocationManager.locationServicesEnabled() {
      // Request location usage in async if needed
      lm?.requestWhenInUseAuthorization()
    } else {
      locationServiceDisabledAlert()
    }


//    // URL cache
//    let URLCache = NSURLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 4 * 1024 * 1024, diskPath: "nsurlcache")
//    NSURLCache.setSharedURLCache(URLCache)
    
    return true
  }
  
  func applicationWillResignActive(application: UIApplication) {
    log.verbose("")
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    lm?.stopUpdatingLocation()
  }

  func applicationDidEnterBackground(application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(application: UIApplication) {
    log.verbose("")
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

  }

  func applicationDidBecomeActive(application: UIApplication) {
    log.verbose("")
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    if !CLLocationManager.locationServicesEnabled() {
      locationServiceDisabledAlert()
    }

    // Check current location auth status and initialize service if allowed
    let locationAuthorizationStatus = CLLocationManager.authorizationStatus()
    log.debug("location auth status: \(locationAuthorizationStatus.hashValue)")

    switch locationAuthorizationStatus {
    case CLAuthorizationStatus.AuthorizedAlways:
      initializeLocationWithAuthorizationStatus(locationAuthorizationStatus)
    case CLAuthorizationStatus.AuthorizedWhenInUse:
      initializeLocationWithAuthorizationStatus(locationAuthorizationStatus)
    case CLAuthorizationStatus.NotDetermined:
      log.info("Location service has not been authorized by user yet. Do nothing yet.")
    case CLAuthorizationStatus.Denied:
        locationServiceDisabledAlert(authorizationStatus: locationAuthorizationStatus)
    default:
      log.error("Location auth restricted: \(locationAuthorizationStatus.hashValue)")
      // TODO show note
    }

  }

  func applicationWillTerminate(application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
  
  func applicationDidReceiveMemoryWarning(application: UIApplication) {
    // Clean URL caches
    NSURLCache.sharedURLCache().removeAllCachedResponses()
  }

  // Initialize location manager
  func initializeLocationWithAuthorizationStatus(status: CLAuthorizationStatus) {

    if status == .AuthorizedAlways || status == .AuthorizedWhenInUse {
      
      lm = lm ?? CLLocationManager()
      if let lm = lm {
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.activityType = CLActivityType.Other
        lm.distanceFilter = 10 // meters
        
        if CLLocationManager.locationServicesEnabled() {
          lm.startUpdatingLocation()
          log.debug("started location monitoring")
        } else {
            locationServiceDisabledAlert()
        }
      }

    } else {
      // User disapproved location updates so make sure that we no more use it
      lm?.stopUpdatingLocation()
      log.error("Location service not allowed")
      locationServiceDisabledAlert(authorizationStatus: status)
    }

  }

  private func locationServiceDisabledAlert(authorizationStatus: CLAuthorizationStatus? = nil) {
    log.warning("Location services disabled" + (authorizationStatus == nil ? " on device level." : "") + " Show alert.")

    let errorTitle = NSLocalizedString("Turn on Location Services to Allow BusStop to Determine Your Location", comment: "")
    let errorMessage = "" //NSLocalizedString("Location service disabled", comment: "")
    let alertController = UIAlertController(title: errorTitle, message: errorMessage, preferredStyle: UIAlertControllerStyle.Alert)
    alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: UIAlertActionStyle.Cancel, handler: nil))
    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: UIAlertActionStyle.Default, handler: {_ in
      UIApplication.sharedApplication().openURL( NSURL(string: String(format: "%@BundleID", UIApplicationOpenSettingsURLString))!)
    }))
    UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
  }
  
  func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
    log.debug("didRegisterUserNotificationSettings: \(notificationSettings)")

    if notificationSettings.types == UIUserNotificationType.Alert {
      
    }
  }
  
  func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
    log.debug("didReceiveLocalNotification: \(notification)")
    UIApplication.sharedApplication().applicationIconBadgeNumber = 0
  }
  
  func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
    log.debug("handleActionWithIdentifier: \(notification)")
    UIApplication.sharedApplication().applicationIconBadgeNumber = 0
    completionHandler()
  }

}

// MARK: - CLLocationManagerDelegate
extension AppDelegate: CLLocationManagerDelegate {
  func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
    log.debug("didUpdateLocations: \(locations[0].description)")

    if let latestLoc = locations.last as? CLLocation {
      if latestLoc.horizontalAccuracy > 0 && latestLoc.timestamp.timeIntervalSinceNow > -30 {
        // good enough location received
        NSNotificationCenter.defaultCenter().postNotificationName(AppDelegate.newLocationNotificationName, object: self, userInfo: [AppDelegate.newLocationResult: locations[0]])
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

    initializeLocationWithAuthorizationStatus(status)
  }
}
