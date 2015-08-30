// Copyright (c) 2015 Solipaste Oy
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import UIKit
import CoreLocation
import ReachabilitySwift
import XCGLogger
import Async

let log = XCGLogger.defaultInstance()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  lazy var locationManager = CLLocationManager()

  var locationUpdateTimer: Async?
  var locationUpdateStartTime: NSDate?
  static let newLocationNotificationName = "newLocationNotification"
  static let newLocationResult = "newLocationResult"
  let locationUpdateDurationSeconds = 5.0
  var locations: [CLLocation] = []
  var useTestData = false

  var cacheDirectory: NSURL {
    let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
    return urls[urls.endIndex-1] as! NSURL
  }

  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    
    // Logger configuration
    #if DEBUG
      
      let logPath : NSURL = self.cacheDirectory.URLByAppendingPathComponent("XCGLogger_Log.txt")
      log.setup(logLevel: .Verbose, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: logPath, fileLogLevel: .Debug)
      let shortLogDateFormatter = NSDateFormatter()
      shortLogDateFormatter.locale = NSLocale.currentLocale()
      shortLogDateFormatter.dateFormat = "HH:mm:ss.SSS"
      log.dateFormatter = shortLogDateFormatter
      log.xcodeColorsEnabled = true
      log.xcodeColors[XCGLogger.LogLevel.Info] = XCGLogger.XcodeColor(fg: (147, 147, 255))
    #else
      log.setup(logLevel: .Severe, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: .None)
    #endif

    if let launchOptions = launchOptions {
      if let localNotification = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
        log.debug("Launched with local notification:\n \(localNotification)")
      }
    }
    
    // reset badge if allowed
    if UIApplication.sharedApplication().currentUserNotificationSettings().types & UIUserNotificationType.Badge != nil {
      UIApplication.sharedApplication().applicationIconBadgeNumber = 0
    }

    // Request local notification usage
    UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Badge | .Alert | .Sound, categories: nil))

    if CLLocationManager.locationServicesEnabled() {
      // Request location usage in async if needed
      locationManager.requestWhenInUseAuthorization()
    } else {
      locationServiceDisabledAlert()
    }

    useTestData = NSUserDefaults().boolForKey("UseTestData")

    return true
  }
  
  func applicationWillResignActive(application: UIApplication) {
    log.verbose("")
    
    // Maximize battery on background
    locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

  }

  func applicationDidEnterBackground(application: UIApplication) {
  }

  func applicationWillEnterForeground(application: UIApplication) {
    log.verbose("")

  }

  func applicationDidBecomeActive(application: UIApplication) {
    log.verbose("")

    // reset the default accuracy
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters

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
    locationManager.stopUpdatingLocation()
  }
  
  func applicationDidReceiveMemoryWarning(application: UIApplication) {
    // Clean URL caches
    NSURLCache.sharedURLCache().removeAllCachedResponses()
  }

  // Initialize location manager
  func initializeLocationWithAuthorizationStatus(status: CLAuthorizationStatus) {

    if status == .AuthorizedWhenInUse {
      
      locationManager.delegate = self
      locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
      locationManager.activityType = CLActivityType.AutomotiveNavigation
      locationManager.distanceFilter = 10 // meters
      
      startUpdatingLocationForWhile()

    } else {
      // User disapproved location updates so make sure that we no more use it
      locationManager.stopUpdatingLocation()
      locationManager.stopMonitoringSignificantLocationChanges()
      log.error("Location service not authorized by the user")
      locationServiceDisabledAlert(authorizationStatus: status)
    }

  }
  
  func startUpdatingLocation() {
    locationManager.startUpdatingLocation()
  }
  
  
  func startUpdatingLocationForWhile() {
    log.verbose("")
    if locationUpdateTimer != nil {
      log.debug("Already monitoring. Ignoring.")
      return
    }
    
    if CLLocationManager.locationServicesEnabled() &&
      CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse {
        locations = []
        locationManager.startUpdatingLocation()
        log.debug("started location monitoring")
        locationUpdateStartTime = NSDate()
        locationUpdateTimer = Async.background(after: locationUpdateDurationSeconds, block: handleReceivedLocations)
    } else {
      locationServiceDisabledAlert()
    }
  }
  
  func stopUpdatingLocation(handleReceivedLocations handle: Bool) {
    log.verbose("")
    locationManager.stopUpdatingLocation()
    locationUpdateTimer?.cancel()
    // nil timer means that timer is not running
    locationUpdateTimer = nil
    if handle {
      handleReceivedLocations()
    }
  }

  private func handleReceivedLocations() {

    let monitoringDuration = abs(locationUpdateStartTime?.timeIntervalSinceNow ?? 0)
    log.debug("Location monitoring stopped after \(monitoringDuration) seconds and \(self.locations.count) locations")
    locationManager.stopUpdatingLocation()
    let initialLocation = CLLocation()
    var bestLocation: CLLocation? =
    locations.reduce(nil as CLLocation?) { (best, candidate) in
      if best == nil {
        // ignore initial
        return candidate
      } else if candidate.horizontalAccuracy > 0 && candidate.horizontalAccuracy <= best?.horizontalAccuracy {
        // ignore zero accuracy, prefer more exact and later locations
        return candidate
      } else {
        return best
      }
    }
    if let bestLocation = bestLocation where bestLocation.horizontalAccuracy > 0 {
      NSNotificationCenter.defaultCenter().postNotificationName(AppDelegate.newLocationNotificationName, object: self, userInfo: [AppDelegate.newLocationResult: bestLocation])
    } else {
      log.error("No location found")
    }
    
    // do not keep old locations
    locations.removeAll(keepCapacity: false)
  }

  private func locationServiceDisabledAlert(authorizationStatus: CLAuthorizationStatus? = nil) {
    if UIApplication.sharedApplication().keyWindow?.rootViewController?.presentedViewController is UIAlertController {
      log.debug("Alert controller already visible. Skipping")
      return
    }
    
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
        
        if locationUpdateTimer != nil {
          
          // Store locations in order to handle them later
          self.locations.append(latestLoc)
          if latestLoc.horizontalAccuracy <= 10 {
            stopUpdatingLocation(handleReceivedLocations: true)
          }
          
        } else {
          
          // handle location immediately
          NSNotificationCenter.defaultCenter().postNotificationName(AppDelegate.newLocationNotificationName, object: self, userInfo: [AppDelegate.newLocationResult: latestLoc])
        }
      }
    }
  }
  
  func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
    log.error("Location Manager didFailWithError: \(error)")

    if error == CLError.Denied.rawValue || error == CLError.LocationUnknown.rawValue {
      locationManager.stopUpdatingLocation()
    }
  }
  
  func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
    log.debug("didChangeAuthorizationStatus: \(status.hashValue)")

    initializeLocationWithAuthorizationStatus(status)
  }
}
