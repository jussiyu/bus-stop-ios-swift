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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  var lm: CLLocationManager?


  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    // Override point for customization after application launch.
    let locStatus = CLLocationManager.authorizationStatus()
    println("location auth status: \(locStatus.hashValue)")
    switch locStatus {
    case CLAuthorizationStatus.AuthorizedAlways:
      initLocation(locStatus)
    case CLAuthorizationStatus.AuthorizedWhenInUse:
      initLocation(locStatus)
    case CLAuthorizationStatus.NotDetermined:
      initLocation(locStatus)
    default:
      println("location auth failed: \(locStatus.hashValue)")
    }
    
    return true
  }

  func applicationWillResignActive(application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    lm?.stopMonitoringSignificantLocationChanges()
  }

  func applicationWillEnterForeground(application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    lm?.requestWhenInUseAuthorization()
    if CLLocationManager.locationServicesEnabled() {
      lm?.startMonitoringSignificantLocationChanges()
      println("start location monitoring")
    } else {
      println("location monitoring disabled")
    }
  }

  func applicationDidBecomeActive(application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }

  func initLocation(status: CLAuthorizationStatus) {
    lm = CLLocationManager()
    lm?.delegate = self
    lm?.desiredAccuracy = kCLLocationAccuracyBest
    lm?.activityType = CLActivityType.Other
    lm?.distanceFilter = 100
    switch status {
    case CLAuthorizationStatus.AuthorizedAlways:
      lm?.startUpdatingLocation()
    case CLAuthorizationStatus.AuthorizedWhenInUse:
      lm?.startUpdatingLocation()
    case CLAuthorizationStatus.NotDetermined:
      lm?.requestWhenInUseAuthorization()
    default:
      println("Location service not allowed")
    }

  }

}

extension AppDelegate: CLLocationManagerDelegate {
  func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
    println("didUpdateLocations: \(locations[0].description)")
    NSNotificationCenter.defaultCenter().postNotificationName("newLocationNotif", object: self, userInfo: ["newLocationResult": locations[0]])
  }
  
  func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
    println("Location Manager didFailWithError: \(error)")
    if error == CLError.Denied.rawValue || error == CLError.LocationUnknown.rawValue {
      lm?.stopUpdatingLocation()
    }
  }
  
  func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
    println("didChangeAuthorizationStatus: \(status.hashValue)")
    switch status {
    case CLAuthorizationStatus.AuthorizedAlways:
      lm?.startUpdatingLocation()
    case CLAuthorizationStatus.AuthorizedWhenInUse:
      lm?.startUpdatingLocation()
    default:
      println("Location service not allowed")
    }
  }
}
