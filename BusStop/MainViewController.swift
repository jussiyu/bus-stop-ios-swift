//
//  ViewController.swift
//  jamesonquave
//
//  Created by Jussi Yli-Urpo on 3.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit
import SwiftyJSON
import CoreLocation
import MediumProgressView
import ReachabilitySwift
import XCGLogger
import Async
import TaskQueue
import AudioToolbox

//
// MARK: - UIViewController
//
class MainViewController: UIViewController {
  
  //
  // MARK: - outlets
  //
  @IBOutlet weak var stopTableView: UITableView!
  @IBOutlet weak var vehicleScrollView: HorizontalScroller!
  @IBOutlet weak var vehicleScrollViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var vehicleScrollViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var autoRefreshSwitch: UIBarButtonItem!
  @IBOutlet weak var progressLabel: UILabel!
  
  let progressViewManager = MediumProgressViewManager.sharedInstance
  let reachability = Reachability.reachabilityForInternetConnection()
  
  //
  // MARK: - properties
  //
  let defaultCellIdentifier: String = "StopCell"
  let selectedCellIdentifier: String = "SelectedStopCell"
  var systemSoundID: SystemSoundID = 0
  let stopSoundFileName = "StopSound", stopSoundFileExt = "aif"
  var userNotifiedForSelectedStop = false
  var autoRefresh:Bool = false
  var autoRefreshTimer: NSTimer?
  let autoRefreshIntervalMax = 10.0
  let autoRefreshIntervalMin = 2.0
  var autoRefreshInterval: Double {
    // adjust refresh interval based on how close user is to the selected stop
    if let selectedStop = selectedStop, selectedStopIndex = selectedVehicle?.stopIndexById(selectedStop.id)
        where selectedStopIndex > 0 {
      return cap(pow(Double(selectedStopIndex), 3), min: autoRefreshIntervalMin, max: autoRefreshIntervalMax)
    } else {
      return autoRefreshIntervalMax
    }
  }
  
  var stopTableViewHeader: UILabel?
  
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
      if selectedVehicle == nil {
        self.selectedVehicle = closestVehicles.first
        self.vehicleScrollView.scrollToViewWithIndex(0, animated: true)
        log.info("Selected vehicle reset to first")
        return
      }
      
      if selectedStop != nil && find(closestVehicles, selectedVehicle!) == nil {
        log.info("Unexpaning the lost selected stop \(self.selectedStop?.id)")
        Async.main {
          var title = NSLocalizedString("Lost your stop.", comment:"")
          var message = NSLocalizedString("Your stop was already passed. Stopped tracking your stop.", comment:"")
          let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
          alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK"), style: UIAlertActionStyle.Default, handler: nil))
          self.presentViewController(alert, animated: true, completion: {
            self.unexpandSelectedStop()
            self.selectedVehicle = self.closestVehicles.first
            self.vehicleScrollView.scrollToViewWithIndex(0, animated: true)
          })
        }
      }
    }
  }
  
  var selectedVehicle: VehicleActivity? {
    didSet {
      selectedStop = nil
      
//      if selectedVehicle != nil {
//        defaults.setObject(selectedVehicle?.vehicleRef, forKey: selectedVehicleKey)
//      }
    }
  }
  var selectedVehicleIndex: Int? {
    if let selectedVehicle = selectedVehicle {
      return closestVehicles.indexOf(selectedVehicle)
    } else {
      return nil
    }
  }

  var stops: [String: Stop] = [:]
  var selectedStop: Stop? {
    didSet {
      userNotifiedForSelectedStop = false
    }
  }
  var userLocation: CLLocation? {
    didSet {
      if let userLocation = userLocation {
        closestVehicles = vehicles.getClosestVehicles(userLocation, maxCount: maxVisibleVehicleCount)
      } else  {
        closestVehicles = []
      }
    }
  }
  
  lazy var apiDelegate: [String: APIControllerDelegate] = {

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
          Async.background {
            self.ref.vehicles = Vehicles(fromJSON: results["body"])
            next?(nil)
          }
        } else { // status != success
          handleError(results, next: next)
        }
      }
    }

    class VehicleStopsDelegate :APIDelegateBase {
      override func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
        if results["status"] == "success" {
          Async.background {
            self.ref.vehicles.setStopsFromJSON(results["body"])
            self.ref.vehicles.setLocationsFromJSON(results["body"])
          }.main {
            self.ref.stopTableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Fade)

            // Check if the selected stop is still on the stop list
            if self.ref.selectedStop != nil {
              let selectedStopRow = self.ref.rowForStop(self.ref.selectedStop!)
              if selectedStopRow == nil {
                log.debug("Selected stop \(self.ref.selectedStop!.name) passed")
                if self.ref.autoUnexpandTaskQueue == nil ||
                  self.ref.autoUnexpandTaskQueue!.state == .Completed ||
                  self.ref.autoUnexpandTaskQueue!.state == .Cancelled {
                  log.debug("Launching new auto unexpand")
                  self.ref.autoUnexpandTaskQueue = self.ref.initAutoUnexpandTaskQueue()
                  self.ref.autoUnexpandTaskQueue?.run()
                }
              } else if selectedStopRow == 0 {
                self.ref.notifySelectedStopReached()
              }
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
          Async.background {
            self.ref.stops = Stop.StopsFromJSON(results["body"])
            next?(nil)
          }
        } else { // status != success
          handleError(results, next: next)
        }
      }
    }
    
    return ["vehicleDelegate": VehicleDelegate(ref: self), "vehicleStopsDelegate": VehicleStopsDelegate(ref: self), "stopsDelegate": StopsDelegate(ref: self)]
  }()

  // Define real remote and and test apis to switch between at runtime
  lazy var localApi: APIControllerProtocol = {
    return APIControllerLocal(vehDelegate: self.apiDelegate["vehicleDelegate"]!, stopsDelegate: self.apiDelegate["stopsDelegate"]!, vehStopsDelegate: self.apiDelegate["vehicleStopsDelegate"]!)
  }()
  lazy var remoteApi: APIControllerProtocol = {
    return APIController(vehDelegate: self.apiDelegate["vehicleDelegate"]!, stopsDelegate: self.apiDelegate["stopsDelegate"]!, vehStopsDelegate: self.apiDelegate["vehicleStopsDelegate"]!)
  }()
  lazy var api: APIControllerProtocol = self.remoteApi
  
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
      if self.selectedStop == nil {
        log.info("Task: show closest vehicle headers")
        self.stopTableView.scrollToTop(animated: true)
        self.vehicleScrollView.reloadData()
      }
    }
    
    q.tasks +=~ {results, next in
      log.info("Task: load stops for the selected vehicle")
      self.refreshStopsForSelectedVehicle(queue: q, next: next)
    }
    
    q.tasks +=! {
      log.info("Task: Show stops for the selected vehicle")
//      self.stopTableView.scrollToTop(animated: true)
      self.stopTableView.reloadData()
//      self.stopTableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Fade)
    }
    
    return q
  }

  var autoUnexpandTaskQueue: TaskQueue?
  func initAutoUnexpandTaskQueue() -> TaskQueue {
    let q = TaskQueue()

    var i = 0
    q.tasks +=! {
      self.autoUnexpandTaskQueueProgress = NSLocalizedString("Hopefully you hace a nice ride! Ending tracking now", comment: "")
    }
    
    q.tasks +=! {[weak q] result, next in
      if i++ > 6 {
        next(nil)
      } else {
        
        println("sleeping \(i)")
        self.autoUnexpandTaskQueueProgress! += "."
        self.stopTableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Fade)
        q?.retry(delay: 1)
      }
    }
 
    q.tasks +=! {
      self.unexpandSelectedStop()
      self.autoUnexpandTaskQueueProgress = nil
    }

    return q
  }
  var autoUnexpandTaskQueueProgress: String?
  
  
  
  //
  // MARK: - lifecycle
  //
  override func viewDidLayoutSubviews() {
  }

  override func viewDidAppear(animated: Bool) {
  }

  override func viewDidLoad() {
    log.verbose("")
    super.viewDidLoad()
    
    vehicleScrollView.delegate = self
  
    // Autorefresh
    autoRefresh = (autoRefreshSwitch.customView as! UISwitch).on
    
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
    log.verbose("deinit")
    NSNotificationCenter.defaultCenter().removeObserver(self)
    
    if systemSoundID != 0 {
      AudioServicesDisposeSystemSoundID(systemSoundID)
      self.systemSoundID = 0
    }
  }

  
  
  //
  // MARK: - actions
  //
  @IBAction func autoRefreshToggled(sender: AnyObject) {
    if let toggle = autoRefreshSwitch.customView as? UISwitch {
      autoRefresh = toggle.on
      initAutoRefreshTimer(andFire: true)
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
              self.stopTableView.hidden = false
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
    (autoRefreshSwitch.customView as! UISwitch).on = autoRefresh
    
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

  
  func stopForRow(row: Int) -> Stop? {
    if let selectedVehicle = selectedVehicle where selectedVehicle.stops.count > row {
      let vehicleActivityStop = selectedVehicle.stops[row]
      if let stop = stops[vehicleActivityStop.id] {
        return stop
      } else {
        log.warning("Stop for row \(row) does exist in the stop list")
        return nil
      }
    } else {
      log.info("Table has no row \(row)")
      return nil
    }
  }
  
  func rowForStop(stop: Stop) -> Int? {
    let row = selectedVehicle?.stopIndexById(stop.id)
    if row == nil {
      log.warning("Selected vehicle does not currenly have this stop")
    }
    return row
  }

  private func notifySelectedStopReached() {
    if userNotifiedForSelectedStop {
      return
    }
    userNotifiedForSelectedStop = true
    
    if UIApplication.sharedApplication().applicationState == .Active {
      playSelectedStopReachedAlert()
    } else {
      UIApplication.sharedApplication().cancelAllLocalNotifications()
      let localNotification = UILocalNotification()
      localNotification.fireDate = nil
      localNotification.soundName = "\(stopSoundFileName).\(stopSoundFileExt)"
      localNotification.alertBody = NSLocalizedString("\(selectedStop!.name) is the next one!", comment: "")
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
    
    NSNotificationCenter.defaultCenter().removeObserver(self, name: AppDelegate.newLocationNotificationName, object: nil)
    
    if initialRefreshTaskQueue?.state == .Running {
      initialRefreshTaskQueue?.pause()
    }
    
    // start location updates if user has selected a stop
    if selectedStop != nil {
      appDelegate.startUpdatingLocation()
    }
  }
  
  func applicationDidBecomeActive(notification: NSNotification) {
    log.verbose("")
    
    extendProgressLabelTextWith(NSLocalizedString("Aquiring location...", comment: ""))
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "locationUpdated:", name: AppDelegate.newLocationNotificationName, object: nil)
    
    refreshAll()
  }
  
  func applicationWillTerminate(notification: NSNotification) {
    log.verbose("")
  }
}


//
// MARK: - UITableViewDataSource
//
extension MainViewController: UITableViewDataSource {
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

    // if a stop is selected then only it will be shown
    if let selectedStop = selectedStop {
      return 1
    } else {
      return selectedVehicle?.stops.count ?? 0
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    
    if let selectedStop = selectedStop, selectedVehicle = selectedVehicle {
      
      // selected cell
      let cell = tableView.dequeueReusableCellWithIdentifier(selectedCellIdentifier, forIndexPath:indexPath) as! SelectedStopTableViewCell
      
      // Return the currently selected stop
      let style = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
      style.hyphenationFactor = 1.0
      style.alignment = .Center
      
      let string = NSAttributedString(string: "\(selectedStop.name)\n(\(selectedStop.id))", attributes: [NSParagraphStyleAttributeName:style])
      cell.stopNameLabel.attributedText = string
      let stopNameLabelFont = UIFont(descriptor: UIFontDescriptor.preferredDescriptorWithStyle(UIFontTextStyleHeadline, oversizedBy: 16), size: 0)
      cell.stopNameLabel.font = stopNameLabelFont
      

      if let selectedStopIndex = selectedVehicle.stopIndexById(selectedStop.id) {
        var stopDistance: String?
        if let userLocationInVehicle = selectedVehicle.location {
            stopDistance = selectedStop.distanceFromUserLocation(userLocationInVehicle)
        }
        var distanceHintText = String(format: NSLocalizedString("%d stop(s) before your stop", comment: ""), selectedStopIndex)
        
        if selectedStopIndex < selectedVehicle.stops.count {
          let stop = selectedVehicle.stops[selectedStopIndex]
          let minutesUntilSelectedStop = Int(floor(stop.expectedArrivalTime.timeIntervalSinceNow / 60))
          var timeHintText: String?
          if minutesUntilSelectedStop >= 0 {
            timeHintText = String(format: NSLocalizedString(
                "Arriving at your stop in about %d minutes(s)", comment: ""), minutesUntilSelectedStop)
          } else {
            timeHintText = String(format: NSLocalizedString(
                "Arriving at your stop very soon!", comment: ""), minutesUntilSelectedStop)
          }
          distanceHintText += "\n\(timeHintText!)"
        }
        
        cell.distanceHintLabel.text = distanceHintText.stringByReplacingOccurrencesOfString(
            "\\n", withString: "\n", options: nil)
      } else {
        cell.distanceHintLabel.text = autoUnexpandTaskQueueProgress ?? ""
      }

      // Delay message
      let delayMinutes = Int(round(abs(selectedVehicle.delay / 60)))
      let delaySeconds = Int(round(abs(selectedVehicle.delay % 60)))
      if selectedVehicle.delay > 0 {
        cell.delayLabel.text = String( format: NSLocalizedString("Behind schedule\nby %d min %d s", comment: ""), delayMinutes, delaySeconds)
      } else if selectedVehicle.delay < 0 {
        cell.delayLabel.text = String( format: NSLocalizedString("Ahead of schedule\nby %d min %d s", comment: ""), delayMinutes, delaySeconds)
      } else {
        cell.delayLabel.text = ""
      }
    
      // Close button
      cell.closeButton.setTitle(NSLocalizedString("Stop tracking", comment: ""), forState: .Normal)
      cell.closeButton.removeTarget(nil, action: nil, forControlEvents: .TouchUpInside)
      cell.closeButton.addTarget(self, action: "selectedStopCloseButtonPressed:", forControlEvents: .TouchUpInside)
    
      return cell

    } else {  // selectedStop == nil
      
      let cell = tableView.dequeueReusableCellWithIdentifier(defaultCellIdentifier, forIndexPath:indexPath) as! UITableViewCell
      
      if let selectedVehicle = selectedVehicle {
        let rowToBeReturned = indexPath.row
        
        if let stop = stopForRow(rowToBeReturned) {
          cell.textLabel?.text = "\(stop.name) (\(stop.id))"
        } else {
          cell.textLabel?.text = NSLocalizedString("Unknown stop", comment: "")
          log.error("Unknown stop at row \(rowToBeReturned)")
        }
      } else {
        
        log.warning("Not vehicle selected")
      }
      
      return cell
    }
  }
  
  func selectedStopCloseButtonPressed(sender: AnyObject) {
    log.verbose("")
  
    unexpandSelectedStop()
  }
  
}


//
// MARK: - UITableViewDelegate
//
extension MainViewController: UITableViewDelegate {
  
  func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    stopTableViewHeader = UILabel()
    if closestVehicles.count > 0 {
      if selectedStop == nil {
        stopTableViewHeader!.text = NSLocalizedString("Choose your stop", comment: "")
      } else {
        stopTableViewHeader!.text = NSLocalizedString("Now tracking your stop", comment: "")
      }
    } else {
      stopTableViewHeader!.text = ""
    }
    stopTableViewHeader!.textAlignment = .Center
    stopTableViewHeader!.backgroundColor = UIColor.whiteColor()
    return stopTableViewHeader
  }
  
  func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 22
  }
  
  func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
    if selectedStop == nil {
      return tableView.rowHeight
    } else {
      return tableView.bounds.height - (stopTableViewHeader?.bounds.height ?? 0)
    }
  }

  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    log.verbose("vehicleScrollView:didSelectRowAtIndexPath: \(indexPath.row)")

    if selectedStop == nil {
      expandStopAtIndexPath(indexPath)
    } else {
      // There is a dedicated close button on the view so do nothing here
    }

  }
  
  func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
    
  }

  func scrollViewDidScroll(scrollView: UIScrollView) {
    // Dim the vehicle scroller and move it up
    // Also slide adjacent headers to the side
   
    // Do nothing if all rows fit so that bouncing does nothing
    if scrollView.bounds.height < scrollView.contentSize.height {

      // scroll stop table view up and minimize vehicle scroller
      // Use the positive value of the table scroll offset to animate other views
      let offset = max(scrollView.contentOffset.y, 0)
      //    log.debug("vehicleScrollView vertical offset: \(offset)")
      expandStopTableViewByOffset(offset)

    } else {
      
      // ensure that everything is reset to normal
      resetVehicleScrollView()
    }
  }
  
  private func expandStopTableView() {
    if let selectedVehicleIndex = selectedVehicleIndex,
        selectedVehicleHeaderView = vehicleScrollView.viewAtIndex(selectedVehicleIndex) as? VehicleHeaderView {

      expandStopTableViewByOffset(selectedVehicleHeaderView.bounds.height +
        selectedVehicleHeaderView.layoutMargins.bottom)
      stopTableView.layoutIfNeeded()
    }
  }
  
  private func expandStopTableViewByOffset(offset: CGFloat) {
    
    if let selectedVehicleIndex = selectedVehicleIndex,
        selectedVehicleHeaderView = vehicleScrollView.viewAtIndex(selectedVehicleIndex) as? VehicleHeaderView {

      // Make horizontal scroller smaller
      vehicleScrollView.shrinkViewByOffset(offset)
          
      // scroll table view up to match current header view bottom
      vehicleScrollViewBottomConstraint.constant = -min(offset, selectedVehicleHeaderView.bounds.height +  selectedVehicleHeaderView.layoutMargins.bottom) + selectedVehicleHeaderView.layoutMargins.bottom
    }
  }
  
  private func unexpandStopTableView() {
    expandStopTableViewByOffset(0)

  }
  
  private func resetVehicleScrollView() {
    for viewIndex in 0..<vehicleScrollView.viewCount {
      if let view = vehicleScrollView.viewAtIndex(viewIndex) as? VehicleHeaderView {
        view.alpha = 1
        view.transform = CGAffineTransformIdentity
        view.fadeOutByOffset(0)
      }
    }
  }
  
  private func expandStopAtIndexPath(indexPath: NSIndexPath) {
    stopTableView.deselectRowAtIndexPath(indexPath, animated: true)
    
    vehicleScrollView.touchEnabled = false
    stopTableView.scrollEnabled = false

    // no row was selected when the row was tapped => remove other rows
    
    // store the stop for the selected row
    selectedStop = stopForRow(indexPath.row)
    if selectedStop == nil {
      // Ignore unknown stops
      return
    }
    
    // we know the row
    let rowForSelectedStop = indexPath.row
    
    // pick all the rows but the currently selected one
    var indexPathsOnAbove = [NSIndexPath]()
    for row in 0 ..< rowForSelectedStop {
      let indexPath = NSIndexPath(forRow: row, inSection: 0)
      indexPathsOnAbove.append(indexPath)
    }
    var indexPathsOnBelow = [NSIndexPath]()
    let rowCount = selectedVehicle?.stops.count ?? 0
    if rowForSelectedStop + 1 < rowCount {
      for row in (rowForSelectedStop + 1) ..< rowCount {
        let indexPath = NSIndexPath(forRow: row, inSection: 0)
        indexPathsOnBelow.append(indexPath)
      }
    }
    
    // Maximize the table view
    expandStopTableView()
    
    // perform the correct update operation
    stopTableView.beginUpdates()
    if let header = stopTableViewHeader {
      header.text = NSLocalizedString("Now tracking your stop", comment: "")
    }
    stopTableView.deleteRowsAtIndexPaths(indexPathsOnAbove, withRowAnimation: .Fade)
    stopTableView.deleteRowsAtIndexPaths(indexPathsOnBelow, withRowAnimation: .Fade)
    
    stopTableView.endUpdates()
    stopTableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Fade)
    
    autoRefresh = true
    initAutoRefreshTimer()
    
  }

  private func unexpandSelectedStop() {
    autoUnexpandTaskQueue?.cancel()
    
    appDelegate.stopUpdatingLocation(handleReceivedLocations: false)
    
    vehicleScrollView.touchEnabled = true
    stopTableView.scrollEnabled = true

    stopTableView.deselectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), animated: true)
    // the tapped (and only) row was already selected => add other rows back
    
    // calculate the final row for the selected stop (or nil)
    var newRowForSelectedStop = selectedStop != nil ? rowForStop(selectedStop!) : nil
    
    // reset the selection
    selectedStop = nil
    
    // pick all the rows but the currently selected one (assume as already moved to the new row)
    var indexPathsOnAbove = [NSIndexPath]()
    if let rowForSelectedStop = newRowForSelectedStop { // skip if the stop does not exist anymore
      for row in 0 ..< rowForSelectedStop {
        let indexPath = NSIndexPath(forRow: row, inSection: 0)
        indexPathsOnAbove.append(indexPath)
      }
    }
    log.debug("About to insert \(indexPathsOnAbove.count) stop(s) above")
    
    var indexPathsOnBelow = [NSIndexPath]()
    let rowCount = selectedVehicle?.stops.count ?? 0

    // If the selected stop does not exist anymore so add *all* rows from row #0 onwards
    let insertNewRowsFromThisRow = newRowForSelectedStop != nil ? newRowForSelectedStop! + 1 : 0
    if insertNewRowsFromThisRow < rowCount {
      for row in insertNewRowsFromThisRow ..< rowCount {
        let indexPath = NSIndexPath(forRow: row, inSection: 0)
        indexPathsOnBelow.append(indexPath)
      }
    }
    log.debug("About to insert \(indexPathsOnBelow.count) stop(s) below")

    // perform the correct update operation
    stopTableView.beginUpdates()

    if let header = stopTableViewHeader {
      header.text = NSLocalizedString("Choose your stop", comment: "")
    }

    // decide what to do with the current row (on row #0)
    let currentSelectedRowIndexPath = NSIndexPath(forRow: 0, inSection: 0)
    if let newRowForSelectedStop = newRowForSelectedStop {
      // the selected row will exist on the same row (#0) in the restored list so update it
      log.debug("new row for the selected stop is \(newRowForSelectedStop)")
      if newRowForSelectedStop == 0 {
        stopTableView.reloadRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .Fade)
      } else {
        // the selected row will exist on a new row in the restored list so move it
//        stopTableView.moveRowAtIndexPath(currentSelectedRowIndexPath, toIndexPath: NSIndexPath(forRow: newRowForSelectedStop, inSection: 0))
        stopTableView.reloadRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .None)
      }
      
    } else { // newRowForSelectedStop == nil
      
      log.debug("the selected stop not visible anymore")
      // row does not exist anymore so delete it
      stopTableView.deleteRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .Fade)
    }

    // safe to forget now which row was selected
    stopTableView.insertRowsAtIndexPaths(indexPathsOnAbove, withRowAnimation: UITableViewRowAnimation.Top)
    stopTableView.insertRowsAtIndexPaths(indexPathsOnBelow, withRowAnimation: UITableViewRowAnimation.Bottom)
    
    stopTableView.endUpdates()

    // Reset the size of the table view
    unexpandStopTableView()
    if let newRowForSelectedStop = newRowForSelectedStop {
      stopTableView.scrollToRowAtIndexPath(NSIndexPath(forRow: newRowForSelectedStop, inSection: 0), atScrollPosition: .None, animated: true)
    }
    
    autoRefresh = false
    initAutoRefreshTimer()

  }
  
}


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
    let count = min(maxVisibleVehicleCount, vehicles.count)
    log.debug("numberOfItemsInHorizontalScroller: \(count)")
    return count
  }
  
  func horizontalScroller(horizontalScroller: HorizontalScroller, didScrollToViewAtIndex: Int) {
    log.verbose("horizontalScroller(_:didScrollToViewAtIndex: \(didScrollToViewAtIndex))")

    if closestVehicles.count > didScrollToViewAtIndex {
      selectedVehicle = closestVehicles[didScrollToViewAtIndex]
    } else {
      if closestVehicles.count > 0 {
        log.error("vehicle with invalid index selected")
      }
      selectedVehicle = nil
    }

    if selectedVehicle != nil {
      refreshStopsForSelectedVehicle(queue: nil) {_ in Async.main {self.progressViewManager.hideProgress()} }
    }
  }
  
  func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller) {
    stopTableView.scrollToTop(animated: true)
    resetVehicleScrollView()
  }
  
  func horizontalScrollerTapped(horizontalScroller: HorizontalScroller, numberOfTaps: Int) {
    self.progressViewManager.showProgress()
    
    
    if numberOfTaps == 3 {
      // Switch between remote and local test data
      selectedVehicle = nil
        // TODO: switch to local APIController
      if api is APIController {
        self.api = self.localApi
      } else {
        self.api = self.remoteApi
      }

    }
    
    stopTableView.scrollToTop(animated: true)
    resetVehicleScrollView()

    if selectedStop != nil {
        appDelegate.startUpdatingLocationForWhile()
    }
    refreshAll()
  }
}