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
import SwiftyJSON
import CoreLocation
import MediumProgressView
import ReachabilitySwift
import XCGLogger
import AsyncLegacy
import TaskQueue
import AudioToolbox

//
// MARK: - UIViewController
//

protocol StopDelegate {
  func getSelectedStopId() -> String?
  func unselectStop()
  func reloadStops()
  func scrollToTopWithAnimation(animated: Bool)
}

//
// MARK: - MainDelegate implementation
//
extension MainViewController : MainDelegate {
  
  func resetVehicleScrollView() {
    for viewIndex in 0..<vehicleScrollView.viewCount {
      if let view = vehicleScrollView.viewAtIndex(viewIndex) as? VehicleHeaderView {
        view.alpha = 1
        view.transform = CGAffineTransformIdentity
        view.fadeOutByOffset(0)
      }
    }
  }
  
  func getSelectedVehicle() -> VehicleActivity? {
    return selectedVehicle
  }

  func expandStopContainer() {
    if let selectedVehicleIndex = selectedVehicleIndex,
      selectedVehicleHeaderView = vehicleScrollView.viewAtIndex(selectedVehicleIndex) as? VehicleHeaderView {
        
        expandStopContainerByOffset(selectedVehicleHeaderView.bounds.height +
          selectedVehicleHeaderView.layoutMargins.bottom)
        stopTableContainerView.layoutIfNeeded()
    }
  }
  
  func expandStopContainerByOffset(offset: CGFloat) {
    
    if let selectedVehicleIndex = selectedVehicleIndex,
      selectedVehicleHeaderView = vehicleScrollView.viewAtIndex(selectedVehicleIndex) as? VehicleHeaderView {
        
        // Make horizontal scroller smaller
        vehicleScrollView.shrinkViewByOffset(offset)
        
        // scroll table view up to match current header view bottom
        vehicleScrollViewBottomConstraint.constant = -min(offset, selectedVehicleHeaderView.bounds.height +  selectedVehicleHeaderView.layoutMargins.bottom) + selectedVehicleHeaderView.layoutMargins.bottom
    }
  }
  
  func stopSelected() {
    // reset notifier flag
    userNotifiedForSelectedStop = false
    
    initAutoRefreshTimer(andFire: true)
    vehicleScrollView.touchEnabled = false
    expandStopContainer()
  }
  
  func stopUnselected() {
    initAutoRefreshTimer()
    vehicleScrollView.touchEnabled = true
    
    // hide stop table temporarily as it's probably out of date
    stopTableContainerView.hidden = true
    
    // minimize stop container
    expandStopContainerByOffset(0)
    
    // Refresh vehicle as they were not updated while stop was selected
    progressViewManager.showProgress()
    refreshVehicles(queue: nil) {_ in self.progressViewManager.hideProgress()}
  }
  
  func getUserLocation() -> CLLocation? {
    return userLocation
  }
  
  func refresh(ready: () -> Void) {
    Async.main {self.progressViewManager.showProgress() }
    refreshStopsForSelectedVehicle(queue: nil) {_ in
      Async.main {
        ready()
        self.progressViewManager.hideProgress()
      }
    }
  }
  
  func selectedStopReached() {
    notifySelectedStopReached()
  }
}




//
// MARK: - UIViewController implementation
//////////////////////////////////////////
//

class MainViewController: UIViewController {
  
  //
  // MARK: - outlets
  //
  
  @IBOutlet weak var stopTableContainerView: UIView!
  @IBOutlet weak var vehicleScrollView: HorizontalScroller!
  @IBOutlet weak var vehicleScrollViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var vehicleScrollViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var refreshButtonItem: UIBarButtonItem!
  @IBOutlet weak var progressLabel: UILabel!
  
  let progressViewManager = MediumProgressViewManager.sharedInstance
  let reachability = Reachability.reachabilityForInternetConnection()
  
  //
  // MARK: - properties
  //
  
  var stopDelegate: StopDelegate?
  var systemSoundID: SystemSoundID = 0
  let stopSoundFileName = "StopSound", stopSoundFileExt = "aif"
  var userNotifiedForSelectedStop = false
  var autoRefresh: Bool {return selectedStopId  != nil}
  var autoRefreshTimer: NSTimer?
  let autoRefreshIntervalMax = 10.0
  let autoRefreshIntervalMin = 2.0
  var autoRefreshInterval: Double {
    // adjust refresh interval based on how close user is to the selected stop
    if let selectedStopId = selectedStopId, selectedStopIndex = selectedVehicle?.stopIndexById(selectedStopId)
        where selectedStopIndex > 0 {
      return cap(pow(Double(selectedStopIndex), 3), min: autoRefreshIntervalMin, max: autoRefreshIntervalMax)
    } else {
      return autoRefreshIntervalMax
    }
  }
  
  let maxVisibleVehicleCount = 10
  var vehicles = Vehicles() {
    didSet {
      if let userLocation = userLocation {
        closestVehicles = vehicles.getClosestVehicles(userLocation, maxCount: maxVisibleVehicleCount)
      } else  {
        closestVehicles = []
      }
    }
  }
  
  var closestVehicles: [VehicleActivity] = [] {
    didSet {
      if selectedStopId == nil {
        self.selectedVehicleRef = closestVehicles.first?.vehicleRef
        if !self.vehicleScrollView.shouldScrollToViewWithIndex(0, animated: true) {
          // there was no need to scroll but refresh stops for the current (first) vehicle anyway
          progressViewManager.showProgress()
          refreshStopsForSelectedVehicle(queue: nil) {_ in Async.main {self.progressViewManager.hideProgress()} }
        }
        log.info("Selected vehicle reset to first")
        return
      }
      
      if selectedStopId != nil && find(closestVehicles, selectedVehicle!) == nil {
        log.info("Unexpaning the lost selected stop \(self.selectedStopId)")
        Async.main {
          var title = NSLocalizedString("Lost your stop.", comment:"")
          var message = NSLocalizedString("Your stop was already passed. Stopped tracking your stop.", comment:"")
          let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
          alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK"), style: UIAlertActionStyle.Default, handler: nil))
          self.presentViewController(alert, animated: true, completion: {
            self.stopDelegate?.unselectStop()
            self.selectedVehicleRef = self.closestVehicles.first?.vehicleRef
            self.vehicleScrollView.shouldScrollToViewWithIndex(0, animated: true)
          })
        }
      }
    }
  }
  
  var selectedVehicleRef: String? {
    didSet {
      if stopDelegate?.getSelectedStopId() != nil {
        stopDelegate?.unselectStop()
      }
      
      //      if selectedVehicle != nil {
      //        defaults.setObject(selectedVehicle?.vehicleRef, forKey: selectedVehicleKey)
      //      }
    }
  }
  
  // Not retained as a strong reference in order to avoid duplicates after an vehicles refresh
  var selectedVehicle: VehicleActivity? {
    for v in closestVehicles {
      if v.vehicleRef == selectedVehicleRef {
        return v
      }
    }
    return nil
  }

  var selectedVehicleIndex: Int? {
    if let selectedVehicle = selectedVehicle {
      return closestVehicles.indexOf(selectedVehicle)
    } else {
      return nil
    }
  }

  /// a thread specific instance - do not reuse across threads
  var stopDBManager: StopDBManager { return StopDBManager.sharedInstance }

  var selectedStopId: String? { return stopDelegate?.getSelectedStopId() }

  var userLocation: CLLocation? {
    didSet {
      if let userLocation = userLocation {
        closestVehicles = vehicles.getClosestVehicles(userLocation, maxCount: maxVisibleVehicleCount)
      } else  {
        closestVehicles = []
      }
    }
  }
  
  lazy var apiDelegate: Delegates = {

    // Common functionality
    class APIDelegateBase: APIControllerDelegate {
      let ref: MainViewController
      init(ref: MainViewController) {
        self.ref = ref
      }

      func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
      }
      
      func didReceiveError(urlerror: NSError, next: ApiControllerDelegateNextTask?) {
        self.ref.initialRefreshTaskQueue?.removeAll()
        next?("URL error \(urlerror)")
      }
      
      func handleError(results: JSON, next: ApiControllerDelegateNextTask?) {
        Async.main {
          let errorTitle = results["data"]["title"] ?? "unknown error"
          let errorMessage = results["data"]["message"] ?? "unknown details"
          let alertController = UIAlertController(title: "Network error", message:
            "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
          alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
          self.ref.presentViewController(alertController, animated: true, completion: nil)
          self.ref.initialRefreshTaskQueue?.removeAll()
          next?("JSON error")
        }
      }
    }
    
    // API call specific delegates
    class VehicleDelegate :APIDelegateBase {
      override func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
        if results["status"] == "success" {
          self.ref.vehicles = Vehicles(fromJSON: results["body"])
          next?(nil)
        } else { // status != success
          handleError(results, next: next)
        }
      }
    }

    class VehicleStopsDelegate :APIDelegateBase {
      override func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
        if results["status"] == "success" {
          self.ref.vehicles.setStopsFromJSON(results["body"])
          self.ref.vehicles.setLocationsFromJSON(results["body"])
          Async.main {
            self.ref.stopDelegate?.reloadStops()
            UIView.animateWithDuration(0.3) {
              self.ref.stopTableContainerView.hidden = false
            }
            next?(nil)
          }
        } else { // status != success
          handleError(results, next: next)
        }
      }
    }
    
    class StopsDelegate: APIDelegateBase {
      
      override func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
        if results["status"] == "success" {
          self.ref.stopDBManager.initFromJSON(results["body"])
          next?(nil)
        } else { // status != success
          handleError(results, next: next)
        }
      }
    }
    
    return Delegates(
      vehicleDelegate: VehicleDelegate(ref: self),
      stopsDelegate: StopsDelegate(ref: self),
      vehicleStopsDelegate: VehicleStopsDelegate(ref: self))
  }()

  // Define real remote and and test apis to switch between at runtime
  lazy var localApi: APIControllerProtocol = {
    let api = APIControllerLocal.sharedInstance() as! APIControllerLocal
    api.vehicleDelegate = self.apiDelegate.vehicleDelegate
    api.stopsDelegate = self.apiDelegate.stopsDelegate
    api.vehicleStopsDelegate = self.apiDelegate.vehicleStopsDelegate
    return api
  }()
  lazy var remoteApi: APIControllerProtocol = {
    let api = APIController.sharedInstance() as! APIController
    api.vehicleDelegate = self.apiDelegate.vehicleDelegate
    api.stopsDelegate = self.apiDelegate.stopsDelegate
    api.vehicleStopsDelegate = self.apiDelegate.vehicleStopsDelegate
    return api
  }()
  lazy var api: APIControllerProtocol = self.appDelegate.useTestData ? self.localApi : self.remoteApi
  
  var initialRefreshTaskQueue: TaskQueue?
  
  func initInitialRefreshTaskQueue() -> TaskQueue {
    let q = TaskQueue()
    
    q.tasks +=! {
      log.info("Task: show progress")
      self.progressViewManager.showProgress()
    }
    
    q.tasks +=~ { result, next in
      log.info("Task: load stop data")
      self.extendProgressLabelTextWith(NSLocalizedString("Refreshing stop information from network...", comment: ""))
      self.refreshStops(queue: q, next: next)
    }
    
    q.tasks +=~ { result, next in
      log.info("Task: load vehicle headers")
      self.extendProgressLabelTextWith(NSLocalizedString("Refreshing bus information from network...", comment: ""))
      self.refreshVehicles(queue: q, next: next)
    }

    q.tasks +=! {
      self.extendProgressLabelTextWith(NSLocalizedString("Bus data loaded.", comment: ""))
    }
    
    var locationCheckCounter = 0
    q.tasks +=~ {[weak q] result, next in
      log.info("Task: waiting for location")
      // get closes vehicle
      if self.userLocation == nil {

        if locationCheckCounter++ < 10 {
          q!.retry(delay: 0.5)

        } else {
          
          // Pause and try to continue later
          q!.pause()
          self.progressViewManager.hideProgress()
          locationCheckCounter = 0

          Async.main {
            var title = CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse ?
              NSLocalizedString("Failed to acquire your location.", comment:"") :
              NSLocalizedString("To use BusStop, please allow BusStop to use location data in phone settings.", comment:"")
            let alert = UIAlertController(title: title, message: nil, preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK"), style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            self.extendProgressLabelTextWith(NSLocalizedString("Failed to acquire location.", comment: ""))
          }
          q!.retry()
          
        }
      } else {
        next(nil)
      }
    }
    
    q.tasks +=! {
      if self.selectedStopId == nil {
        log.info("Task: show closest vehicle headers")
        self.stopDelegate?.scrollToTopWithAnimation(true)
        self.vehicleScrollView.reloadData()
      }
    }
    
    q.tasks +=~ {results, next in
      log.info("Task: load stops for the selected vehicle")
      self.refreshStopsForSelectedVehicle(queue: q, next: next)
    }
    
    q.tasks +=! {
//      log.info("Task: Show stops for the selected vehicle")
//      self.stopTableView.scrollToTop(animated: true)
//      self.stopTableView.reloadData()
//      self.stopTableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Fade)
    }
    
    return q
  }
  
  //
  // MARK: - lifecycle
  //
  override func viewDidLoad() {
    log.verbose("")
    super.viewDidLoad()
    
    vehicleScrollView.delegate = self
    
    let refershControl = UIRefreshControl()
  
    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "preferredContentSizeChanged:",
      name: UIContentSizeCategoryDidChangeNotification,
      object: nil)

    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "applicationWillResignActive:",
      name: UIApplicationWillResignActiveNotification,
      object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "applicationDidBecomeActive:",
      name: UIApplicationDidBecomeActiveNotification,
      object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "applicationWillTerminate:",
      name: UIApplicationWillTerminateNotification,
      object: nil)
    
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    // Reachability
    reachability.whenReachable = { reachability in
      self.extendProgressLabelTextWith(NSLocalizedString("Network connectivity resumed. Refreshing data from network...", comment: ""))
      
      log.debug("Now reachable")
      if self.initialRefreshTaskQueue == nil || self.initialRefreshTaskQueue!.state != .Running {
        self.initialRefreshTaskQueue = self.initInitialRefreshTaskQueue()
      }

      self.refreshAll()
    }
    reachability.startNotifier()
  }

  override func viewWillDisappear(animated: Bool) {
    reachability.stopNotifier()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    if systemSoundID != 0 {
      AudioServicesDisposeSystemSoundID(systemSoundID)
      systemSoundID = 0
    }
    // Dispose of any resources that can be recreated.
  }

  deinit {
    log.verbose("")
    NSNotificationCenter.defaultCenter().removeObserver(self)
    
    if systemSoundID != 0 {
      AudioServicesDisposeSystemSoundID(systemSoundID)
      self.systemSoundID = 0
    }
    
    api.invalidateSessions()
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let stopController = segue.destinationViewController as? StopTableViewController {
      stopController.mainDelegate = self
      stopDelegate = stopController
    }

  }
  
  
  //
  // MARK: - actions
  //
  @IBAction func refreshTapped(sender: AnyObject) {
    if let autoRefreshTimer = autoRefreshTimer {
      autoRefreshTimer.fire()
    } else {
      Async.main {self.progressViewManager.showProgress() }
      refreshStopsForSelectedVehicle(queue: nil) {_ in
        Async.main {self.progressViewManager.hideProgress()}
      }
    }
  }

  
  //
  // MARK: - utility functions
  //
  
  private func refreshAll() {
    
    synchronize(self) {
      // if queue is nil then it can be created in default branch
      switch self.initialRefreshTaskQueue?.state ?? .NotStarted {
      case .Paused:
        log.info("RefreshAll resuming paused queue...")
        self.initialRefreshTaskQueue?.resume()
        
      case .Running:
        log.warning("RefreshAll already running")
        0
        
      default:
        log.info("RefreshAll starting fresh queue...")
        
        // Recrated new queue
        self.initialRefreshTaskQueue = self.initInitialRefreshTaskQueue()
        self.initialRefreshTaskQueue!.run {
          Async.main {
            if let q = self.initialRefreshTaskQueue, result = q.lastResult as? String where !result.isBlank {
              self.extendProgressLabelTextWith(NSLocalizedString("Failed to initialize the application", comment: ""))
              log.error("RefreshAll failed: \(result)")
            } else {
              log.info("RefreshAll done successfully!")
              self.extendProgressLabelTextWith(NSLocalizedString("All data loaded", comment: ""))
              self.hideProgressLabel()
            }
            self.progressViewManager.hideProgress()
          }
        }
      }
    }

  }

  private func refreshStops(#queue: TaskQueue?, next: ApiControllerDelegateNextTask?) {
    log.verbose("")
    
    if stopDBManager.stopCount > 0 {
      log.debug("Stops already in DB. No need to reload from network")
      next?(nil)
      return
    }
    
    if reachability.isReachable() {
      api.getStops(next)
    } else {
      showNetworkReachabilityError()

      queue?.removeAll()
      next?("no network connection")
    }
  }

  private func refreshVehicles(#queue: TaskQueue?, next: ApiControllerDelegateNextTask?) {
    log.verbose("")
    
    if reachability.isReachable() {
      api.getVehicleActivityHeaders(next: next)
    } else {
      showNetworkReachabilityError()

      queue?.removeAll()
      next?("no network connection")
    }
  }

  private func refreshStopsForSelectedVehicle(#queue: TaskQueue?, next: ApiControllerDelegateNextTask?) {
    log.verbose("")

    if let selectedVehicleRef = selectedVehicle?.vehicleRef {
      if reachability.isReachable() {
        api.getVehicleActivityStopsForVehicle(selectedVehicleRef, next: next)
      } else {
        showNetworkReachabilityError()

        queue?.removeAll()
        next?("no network connection")
      }
    } else {
      log.warning("no selected vehicle found")
      queue?.removeAll()
      next?(nil)
    }
  }
  
  private func showNetworkReachabilityError() {
    log.warning("Not reachable")
    
    let alert = UIAlertController(title: NSLocalizedString("Cannot connect to network", comment:""), message: NSLocalizedString("Please check that you have network connection.", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.Default, handler: nil))
    presentViewController(alert, animated: true, completion: nil)
  }
  
  private func initAutoRefreshTimer(andFire: Bool = false) {
    Async.main {
      // Use main thread to ensure that invalidate functions correctly
      self.autoRefreshTimer?.invalidate()
      
      if self.autoRefresh {
        
        self.autoRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(
            self.autoRefreshInterval, target: self, selector: "timedRefreshRequested:", userInfo: nil, repeats: false)
        self.autoRefreshTimer?.tolerance = 2
        if andFire {
          self.autoRefreshTimer?.fire()
        }
        log.debug("Autorefresh initialized with \(self.autoRefreshInterval) inteval")
        
      } else {
        log.debug("Autorefresh disabled")
      }
    }
  }

  func timedRefreshRequested(timer: NSTimer) {
    Async.main {self.progressViewManager.showProgress() }
    refreshStopsForSelectedVehicle(queue: nil) {_ in
      Async.main {self.progressViewManager.hideProgress()}
      self.initAutoRefreshTimer(andFire: false)
    }
  }
  
  func extendProgressLabelTextWith(text: String) {
    if progressLabel.text == nil || progressLabel.text!.isEmpty {
      progressLabel.attributedText = NSMutableAttributedString(string: text,
        attributes: [NSForegroundColorAttributeName: UIColor.darkGrayColor()])
    } else {
      let newString = NSMutableAttributedString(string: progressLabel.text!,
        attributes: [NSForegroundColorAttributeName: UIColor.lightGrayColor()])
      let newText = NSAttributedString(string: "\n\(text)",
        attributes: [NSForegroundColorAttributeName: UIColor.darkGrayColor()])
      newString.appendAttributedString(newText)
      progressLabel.attributedText = newString
    }
  }

  func hideProgressLabel() {
    UIView.animateWithDuration( 0.3, animations: {self.progressLabel.alpha = 0},
      completion: {(_) in self.progressLabel.hidden=true})
  }

  private func notifySelectedStopReached() {
    if userNotifiedForSelectedStop {
      // already notified, ignore
      return
    }
    
    userNotifiedForSelectedStop = true
    
    if UIApplication.sharedApplication().applicationState == .Active {
      playSelectedStopReachedAlert()
    } else if let selectedStopId = selectedStopId, stop = stopDBManager.stopWithId(selectedStopId) {
      let stopName = stop.name ?? stop.id
      UIApplication.sharedApplication().cancelAllLocalNotifications()
      let localNotification = UILocalNotification()
      localNotification.fireDate = nil
      localNotification.soundName = "\(stopSoundFileName).\(stopSoundFileExt)"
      localNotification.alertBody = NSLocalizedString("\(stopName) is the next one!", comment: "")
      localNotification.alertAction = NSLocalizedString("Action", comment:"")
      localNotification.repeatInterval = nil
      UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
    }
  }

  
  private func playSelectedStopReachedAlert() {
    let vibrateSystemSoundID = SystemSoundID(kSystemSoundID_Vibrate)
    AudioServicesPlayAlertSound(vibrateSystemSoundID)
    
    if systemSoundID == 0 {
      if let alertSoundURL = NSBundle.mainBundle().URLForResource(stopSoundFileName, withExtension: stopSoundFileExt) {
        let status = AudioServicesCreateSystemSoundID(alertSoundURL, &systemSoundID)
        if status != 0 {
          log.error("Failed to create system sound for stop alert: \(status)")
        }
      } else {
        log.error("Failed to find system sound file for stop alert")
        return
      }
    }

    if systemSoundID != 0 {
      AudioServicesPlaySystemSound(systemSoundID)
    }
  }
}


//
// MARK: - Life cycle notification related notification handlers
//
extension MainViewController {
  
  func applicationWillResignActive(notification: NSNotification) {
    log.verbose("")
    
    api.cancelTasks()
    
    if initialRefreshTaskQueue?.state == .Running {
      initialRefreshTaskQueue?.pause()
    }
    
    // start location updates if user has selected a stop
    if selectedStopId != nil {
      appDelegate.startUpdatingLocation()
    } else {
      // no stop selected so ignore updates from now on
      appDelegate.stopUpdatingLocation(handleReceivedLocations: false)
      NSNotificationCenter.defaultCenter().removeObserver(self, name: AppDelegate.newLocationNotificationName, object: nil)
    }
  }
  
  func applicationDidBecomeActive(notification: NSNotification) {
    log.verbose("")
    
    extendProgressLabelTextWith(NSLocalizedString("Aquiring location...", comment: ""))
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "locationUpdated:", name: AppDelegate.newLocationNotificationName, object: nil)
    
    refreshAll()
  }
  
  func applicationWillTerminate(notification: NSNotification) {
    println("MainViewController:applicationWillTerminate")
  }
}


//
// MARK: - UITableViewDataSource
//
//extension MainViewController: UITableViewDataSource {
//    //
//  
//}


// MARK: - UITableViewDelegate
//
//
//extension MainViewController: UITableViewDelegate {
//  
//  
//}


//
// MARK: - UITextFieldDelegate
//
extension MainViewController: UITextFieldDelegate {
  
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}


//
// MARK: - locationUpdate notification handler
//
extension MainViewController {
  
  @objc func locationUpdated(notification: NSNotification){
    log.verbose("locationUpdate \(notification.name)")
    if let locInfo = notification.userInfo as? [String:CLLocation], newLoc = locInfo[AppDelegate.newLocationResult] {
      if userLocation == nil || userLocation!.moreAccurateThanLocation(newLoc) ||
          !userLocation!.commonHorizontalLocationWith(newLoc) {
        userLocation = newLoc
        log.info("New user loc:  \(self.userLocation?.description)")
        extendProgressLabelTextWith(NSLocalizedString("Location acquired.", comment: ""))
      } else {
        log.info("Existing or worse user loc notified. Ignored.")
      }
    }
  }
}


//
// MARK: - preferredContentSizeChanged notification handler
//
extension MainViewController {
  
  func preferredContentSizeChanged(notification: NSNotification) {
    log.verbose("preferredContentSizeChanged")
    //    vehicleStopTableView takes care of itself
    vehicleScrollView.reloadData()
  }
}

//
// MARK: - HorizontalScrollerDelegate
//
extension MainViewController: HorizontalScrollerDelegate {
  
  // MARK: - Data source functions
  func horizontalScroller(horizontalScroller: HorizontalScroller, existingViewAtIndexPath indexPath: Int) -> UIView? {
    var view: UIView?
    if let userLocation = userLocation where closestVehicles.count > indexPath {
      
      let veh = closestVehicles[indexPath]
      let lineRef = String(format: NSLocalizedString("Line %@", comment: "Line name header"), veh.lineRef)
      let vehicleRef = veh.formattedVehicleRef
      let distance: String = veh.distanceFromUserLocation(userLocation)
      
      view = horizontalScroller.dequeueReusableView(indexPath) as? VehicleHeaderView
      if view != nil {
        VehicleHeaderView.initWithReusedView(view as! VehicleHeaderView, lineRef: lineRef, vehicleRef: vehicleRef, distance: distance)
      }
    } else {
      log.error("No user location or vehicle found!")
      view = UIView()
    }
    
//    log.debug("subView at index \(indexPath): \(view)")
    return view
  }
  
  func horizontalScroller(horizontalScroller: HorizontalScroller, viewAtIndexPath indexPath: Int) -> UIView {
    var view: UIView?
    if let userLocation = userLocation where closestVehicles.count > indexPath {
      
      let veh = closestVehicles[indexPath]
      let lineRef = String(format: NSLocalizedString("Line %@", comment: "Line name header"), veh.lineRef)
      let vehicleRef = veh.formattedVehicleRef
      let distance: String = veh.distanceFromUserLocation(userLocation)
      
      view = VehicleHeaderView(lineRef: lineRef, vehicleRef: vehicleRef, distance: distance)
    } else {
      log.error("No user location or vehicle found!")
      view = UIView()
    }
    
//    log.debug("subView at index \(indexPath): \(view)")
    return view!
  }
  
  func horizontalScrollerNoDataView(horizontalScroller: HorizontalScroller) -> UIView {
    let lineRef = ""
    let vehicleRef = NSLocalizedString("No busses near you", comment: "show as vehicle label when no busses near or no user location known")
    let distance = NSLocalizedString("Tap to refresh", comment: "")

    var noDataView = horizontalScroller.dequeueReusableView(0) as? VehicleHeaderView
    if noDataView != nil {
      VehicleHeaderView.initWithReusedView(noDataView!, lineRef: lineRef, vehicleRef: vehicleRef, distance: distance)
    } else {
      noDataView = VehicleHeaderView(lineRef: lineRef, vehicleRef: vehicleRef, distance: distance)
    }
    
    return noDataView!
  }

  // MARK: - Notification functions
  func numberOfItemsInHorizontalScroller(horizontalScroller: HorizontalScroller) -> Int {
    let count = min(maxVisibleVehicleCount, closestVehicles.count)
    log.debug("numberOfItemsInHorizontalScroller: \(count)")
    return count
  }
  
  func horizontalScroller(horizontalScroller: HorizontalScroller, didScrollToViewAtIndex: Int) {
    log.verbose("horizontalScroller(_:didScrollToViewAtIndex: \(didScrollToViewAtIndex))")

    if closestVehicles.count > didScrollToViewAtIndex {
      selectedVehicleRef = closestVehicles[didScrollToViewAtIndex].vehicleRef
    } else {
      if closestVehicles.count > 0 {
        log.error("vehicle with invalid index selected")
      }
      selectedVehicleRef = nil
    }

    if selectedVehicleRef != nil {
      progressViewManager.showProgress()
      refreshStopsForSelectedVehicle(queue: nil) {_ in Async.main {self.progressViewManager.hideProgress()} }
    }
  }
  
  func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller) {
    stopDelegate?.scrollToTopWithAnimation(true)
    resetVehicleScrollView()
  }
  
  func horizontalScrollerTapped(horizontalScroller: HorizontalScroller, numberOfTaps: Int) {
    self.progressViewManager.showProgress()
    
    
    if numberOfTaps == 3 {
      // Switch between remote and local test data
      selectedVehicleRef = nil
        // TODO: switch to local APIController
      if api is APIController {
        self.api = self.localApi
      } else {
        self.api = self.remoteApi
      }

    }
    
    stopDelegate?.scrollToTopWithAnimation(true)
    resetVehicleScrollView()

    if selectedStopId != nil {
        appDelegate.startUpdatingLocationForWhile()
    }
    refreshAll()
  }
}

//
// MARK: - appDelegate helper
//
extension UIViewController {
  var appDelegate: AppDelegate {
    return UIApplication.sharedApplication().delegate as! AppDelegate
  }
}