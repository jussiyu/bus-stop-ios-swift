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


// MARK: - UIViewController
class MainViewController: UIViewController {
  
  // MARK: - outlets
  @IBOutlet weak var stopTableView: UITableView!
  @IBOutlet weak var vehicleScrollView: HorizontalScroller!
  @IBOutlet weak var vehicleScrollViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var vehicleScrollViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var autoRefreshSwitch: UIBarButtonItem!
  @IBOutlet weak var progressLabel: UILabel!
  
  let progressViewManager = MediumProgressViewManager.sharedInstance
  let reachability = Reachability.reachabilityForInternetConnection()
  
  // MARK: - properties
  let defaultCellIdentifier: String = "StopCell"
  let selectedCellIdentifier: String = "SelectedStopCell"
  var autoRefresh:Bool = false
  var autoRefreshTimer: NSTimer?
  
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
  
  var closestVehicles: [VehicleActivity] = []
  
  var currentVehicle: VehicleActivity? {
    let closestVehicles = self.closestVehicles
    if closestVehicles.count > currentVehicleIndex {
      return closestVehicles[currentVehicleIndex]
    } else {
      return nil
    }
  }

  private var stops: [String: Stop] = [:]

  private var currentVehicleIndex = 0 {
    didSet {
      selectedStop = nil
    }
  }
  private var selectedStop: Stop? {
    didSet {
      systemSoundPlayedForSelectedStop = false
    }
  }
  private var userLocation: CLLocation? {
    didSet {
      if let userLocation = userLocation {
        closestVehicles = vehicles.getClosestVehicles(userLocation, maxCount: maxVisibleVehicleCount)
      } else  {
        closestVehicles = []
      }
    }
  }
  
  private var systemSoundID: SystemSoundID?
  private var systemSoundPlayedForSelectedStop = false
  
  lazy private var api: APIController = {
    
    class APIDelegateBase: APIControllerProtocol {
      let ref: MainViewController
      init(ref: MainViewController) {
        self.ref = ref
      }

      func didReceiveAPIResults(results: JSON, next: APIController.NextTask?) {
      }
      
      func didReceiveError(urlerror: NSError, next: APIController.NextTask?) {
        self.ref.initialRefreshTaskQueue?.removeAll()
        next?("URL error \(urlerror)")
      }
      
      func handleError(results: JSON, next: APIController.NextTask?) {
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
    
    class VehicleDelegate :APIDelegateBase {
      override func didReceiveAPIResults(results: JSON, next: APIController.NextTask?) {
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
      override func didReceiveAPIResults(results: JSON, next: APIController.NextTask?) {
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
                if let queue = self.ref.autoUnexpandTaskQueue where !queue.running {
                  log.debug("Launching auto unexpand")
                  queue.run()
                }
              } else if selectedStopRow == 0 {
                self.ref.playSelectedStopReachedAlert()
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
      
      override func didReceiveAPIResults(results: JSON, next: APIController.NextTask?) {
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
    
    return APIController(vehDelegate: VehicleDelegate(ref: self), stopsDelegate: StopsDelegate(ref: self), vehStopsDelegate: VehicleStopsDelegate(ref:self))
  }()

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
          q?.removeAll()
          Async.main {
            let alert = UIAlertController(title: NSLocalizedString("Cannot acquire your location", comment:""), message: NSLocalizedString("", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
          }
          next("No location")
        }
      } else {
        next(nil)
      }
    }
    
    q.tasks +=! {
      log.info("Task: show closest vehicle headers")
      self.vehicleScrollView.reloadData()
    }
    
    q.tasks +=~ {results, next in
      log.info("Task: load stops for the current vehicle")
      self.refreshStopsForCurrentVehicle(queue: q, next: next)
    }
    
    q.tasks +=! {
      log.info("Task: show closest vehicle headers => load stops for the current vehicle")
      self.stopTableView.hidden = false
      self.extendProgressLabelTextWith(NSLocalizedString("All data loaded", comment: ""))
      self.hideProgressLabel()
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
  
  // MARK: - lifecycle
  override func viewDidLayoutSubviews() {
  }

  override func viewDidAppear(animated: Bool) {
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
    vehicleScrollView.delegate = self
  
    // Autorefresh
    autoRefresh = (autoRefreshSwitch.customView as! UISwitch).on

    autoUnexpandTaskQueue = initAutoUnexpandTaskQueue()
    
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

    // Reachability
    reachability.whenReachable = { reachability in
      self.extendProgressLabelTextWith(NSLocalizedString("Network connectivity resumed. Refreshing data from network...", comment: ""))
      
      log.debug("Now reachable")
      if self.initialRefreshTaskQueue == nil || !self.initialRefreshTaskQueue!.running {
        self.initialRefreshTaskQueue = self.initInitialRefreshTaskQueue()
      }
      if let q = self.initialRefreshTaskQueue where !q.running  {
        q.run {
          Async.main {
            if let q = self.initialRefreshTaskQueue, result = q.lastResult as? String where !result.isBlank {
              self.extendProgressLabelTextWith(NSLocalizedString("Failed to initialize the application", comment: ""))
              log.error("Intial refresh failed: \(result)")
            } else {
              log.info("Intial refresh done successfully by reachability!")
              self.extendProgressLabelTextWith(NSLocalizedString("All data loaded", comment: ""))
              self.stopTableView.hidden = false
              self.hideProgressLabel()
            }
            self.progressViewManager.hideProgress()
          }
        }
      }
    }
    reachability.startNotifier()

  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    extendProgressLabelTextWith(NSLocalizedString("Aquiring location...", comment: ""))
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "locationUpdated:", name: "newLocationNotif", object: nil)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    if systemSoundID != nil {
      AudioServicesDisposeSystemSoundID(systemSoundID!)
      systemSoundID = nil
    }
    // Dispose of any resources that can be recreated.
  }

  
  // MARK: - actions
  @IBAction func autoRefreshToggled(sender: AnyObject) {
    if let toggle = autoRefreshSwitch.customView as? UISwitch {
      autoRefresh = toggle.on
      initAutoRefreshTimer(andFire: true)
    }
  }

  // MARK: - utility functions
  
  private func refreshStops(#queue: TaskQueue?, next: APIController.NextTask?) {
    log.verbose("RefreshStops")
    
    if reachability.isReachable() {
      api.getStops(next)
    } else {
      showNetworkReachabilityError()

      queue?.removeAll()
      next?("no network connection")
    }
  }

  private func refreshVehicles(#queue: TaskQueue?, next: APIController.NextTask?) {
    log.verbose("RefreshVehicles")
    
    if reachability.isReachable() {
      api.getVehicleActivityHeaders(next: next)
    } else {
      showNetworkReachabilityError()

      queue?.removeAll()
      next?("no network connection")
    }
  }

  private func refreshStopsForCurrentVehicle(#queue: TaskQueue?, next: APIController.NextTask?) {
    log.verbose("refreshStopsForVehicle")

    if let currentVehicleRef = currentVehicle?.vehRef {
      if reachability.isReachable() {
        api.getVehicleActivityStopsForVehicle(currentVehicleRef, next: next)
      } else {
        showNetworkReachabilityError()

        queue?.removeAll()
        next?("no network connection")
      }
    } else {
      log.warning("no current vehicle found")
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
    
    autoRefreshTimer?.invalidate()
    if autoRefresh {
      autoRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "timedRefreshRequested:", userInfo: nil, repeats: true)
      if andFire {autoRefreshTimer?.fire()}
      autoRefreshTimer?.tolerance = 2
      log.debug("Refresh enabled")
    } else {
      log.debug("Refresh disabled")
    }
  }

  func timedRefreshRequested(timer: NSTimer) {
    Async.main {self.progressViewManager.showProgress() }
    refreshStopsForCurrentVehicle(queue: nil) { _ in Async.main {self.progressViewManager.hideProgress()} }
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
    if let currentVehicle = currentVehicle where currentVehicle.stops.count > row {
      if let lastPath = currentVehicle.stops[row].lastPathComponent, stop = stops[lastPath] {
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
    if let ref = selectedStop?.ref {
      return currentVehicle?.stopIndexByRef(ref)
    } else {
      log.warning("Current vehicle does not currenly have this stop")
      return nil
    }
  }

  private func playSelectedStopReachedAlert() {
    if systemSoundID  == nil {
      systemSoundID = SystemSoundID(kSystemSoundID_Vibrate)
//      let alertSound = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("pulse", ofType: "m4r")!)
//      if let alertSound = alertSound {
//        AudioServicesCreateSystemSoundID(alertSound, &systemSoundID!)
//      } else {
//        log.debug("failed to find alertSound")
//        return
//      }
    }
    
    // Play only once per stop
    if let systemSoundID = systemSoundID where !systemSoundPlayedForSelectedStop {
      AudioServicesPlayAlertSound(systemSoundID)
      systemSoundPlayedForSelectedStop = true
    }
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
      return currentVehicle?.stops.count ?? 0
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    
    if selectedStop == nil {
      let cell = tableView.dequeueReusableCellWithIdentifier(defaultCellIdentifier, forIndexPath:indexPath) as! UITableViewCell
      
      let currentVehicle = self.currentVehicle
      if currentVehicle != nil {
        
        let rowToBeReturned = indexPath.row
        
        if let stop = stopForRow(rowToBeReturned) {
          cell.textLabel?.text = "\(stop.name) (\(stop.id))"
        } else {
          cell.textLabel?.text = NSLocalizedString("Unknown stop", comment: "")
          log.error("Unknown stop at row \(rowToBeReturned)")
        }
      }
      
      return cell
      
    } else { // selectedStop != nil
      
      // selected cell
      let cell = tableView.dequeueReusableCellWithIdentifier(selectedCellIdentifier, forIndexPath:indexPath) as! SelectedStopTableViewCell
      
      let currentVehicle = self.currentVehicle
      // Return the currently selected stop
      let style = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
      style.hyphenationFactor = 1.0
      style.alignment = .Center
      
      let string = NSAttributedString(string: "\(selectedStop!.name)\n(\(selectedStop!.id))", attributes: [NSParagraphStyleAttributeName:style])
      cell.stopNameLabel.attributedText = string
      let stopNameLabelFont = UIFont(descriptor: UIFontDescriptor.preferredDescriptorWithStyle(UIFontTextStyleHeadline, oversizedBy: 16), size: 0)
      cell.stopNameLabel.font = stopNameLabelFont
      
      if let ref = selectedStop!.ref {
        if let stopsBeforeSelectedStop = currentVehicle?.stopIndexByRef(ref) {
          var stopDistance: String?
          if let userLocationInVehicle = currentVehicle?.location {
            stopDistance = selectedStop!.distanceFromUserLocation(userLocationInVehicle)
          }
          var distanceHintText = String(format: NSLocalizedString("%d stop(s) before your stop", comment: ""), stopsBeforeSelectedStop)
          if let stopDistance = stopDistance {
            distanceHintText += ".\n\(stopDistance)"
          }
          cell.distanceHintLabel.text = distanceHintText.stringByReplacingOccurrencesOfString("\\n", withString: "\n", options: nil)
        } else {
          cell.distanceHintLabel.text = autoUnexpandTaskQueueProgress ?? ""
        }
      }
    
      return cell
    }
  }
  
}


//
// MARK: - UITableViewDelegate
//
extension MainViewController: UITableViewDelegate {
  
  func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    stopTableViewHeader = UILabel()
    if selectedStop == nil {
      stopTableViewHeader!.text = NSLocalizedString("Choose your stop", comment: "")
    } else {
      stopTableViewHeader!.text = NSLocalizedString("Now tracking your stop", comment: "")
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
      unexpandSelectedStop()
    }

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
    if let currentVehicleHeaderView = vehicleScrollView.viewAtIndex(currentVehicleIndex) as? VehicleHeaderView {
      expandStopTableViewByOffset(currentVehicleHeaderView.bounds.height +
        currentVehicleHeaderView.layoutMargins.bottom)
      stopTableView.layoutIfNeeded()
    }
  }
  
  private func expandStopTableViewByOffset(offset: CGFloat) {
    
    if let currentVehicleHeaderView = vehicleScrollView.viewAtIndex(currentVehicleIndex) as? VehicleHeaderView {
      // shink and hide not needed info
      currentVehicleHeaderView.fadeOutByOffset(offset)
      
      // Move adjacent headers to side and him them
      for viewIndex in 0..<vehicleScrollView.viewCount {
        if let view = vehicleScrollView.viewAtIndex(viewIndex) {
          if viewIndex != currentVehicleIndex {
            view.alpha = 1 - offset / 10
            view.transform = CGAffineTransformMakeTranslation(viewIndex > currentVehicleIndex ? offset : -offset, 0)
          } else {
            view.alpha = 1
            view.transform = CGAffineTransformIdentity
          }
        }
      }
      
      // scroll table view up to match current header view bottom
      vehicleScrollViewBottomConstraint.constant = -min(offset, currentVehicleHeaderView.bounds.height +  currentVehicleHeaderView.layoutMargins.bottom) + currentVehicleHeaderView.layoutMargins.bottom
      
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
    let rowCount = currentVehicle?.stops.count ?? 0
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
      header.text = NSLocalizedString("Stop selected", comment: "")
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
    autoUnexpandTaskQueue = initAutoUnexpandTaskQueue()

    stopTableView.deselectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), animated: true)
    // the tapped (and only) row was already selected => add other rows back
    
    // calculate the final row for the selected stop (or nil)
    var newRowForSelectedStop = rowForStop(selectedStop!)
    
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
    let rowCount = currentVehicle?.stops.count ?? 0

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
      header.text = NSLocalizedString("Select your stop", comment: "")
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
    if let locInfo = notification.userInfo as? [String:CLLocation], newLoc = locInfo["newLocationResult"] {
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
  
  func applicationWillResignActive(notification: NSNotification) {
    log.verbose("applicationWillResignActive:")
    NSNotificationCenter.defaultCenter().removeObserver(self)
    initialRefreshTaskQueue?.cancel()
  }

  func applicationDidBecomeActive(notification: NSNotification) {
    log.verbose("applicationDidBecomeActive:")
    initialRefreshTaskQueue = initInitialRefreshTaskQueue()
    initialRefreshTaskQueue?.run {
      Async.main {
        if let q = self.initialRefreshTaskQueue, result = q.lastResult as? String where !result.isBlank {
          self.extendProgressLabelTextWith(NSLocalizedString("Failed to initialize the application", comment: ""))
          log.error("Intial refresh failed: \(result)")
        } else {
          log.info("Intial refresh done successfully!")
          self.extendProgressLabelTextWith(NSLocalizedString("All data loaded", comment: ""))
          self.stopTableView.hidden = false
          self.hideProgressLabel()
        }
        self.progressViewManager.hideProgress()
      }
    }

  }
}


//
// MARK: - HorizontalScrollerDelegate
//
extension MainViewController: HorizontalScrollerDelegate {
  
  // MARK: - Data source functions
  func horizontalScroller(horizontalScroller: HorizontalScroller, viewAtIndexPath indexPath: Int) -> UIView {
    var subView: UIView = UIView()
    if let userLocation = userLocation where closestVehicles.count > indexPath {
      let veh = closestVehicles[indexPath]
      subView = VehicleHeaderView(
        lineRef: String(format: NSLocalizedString("Line %@", comment: "Line name header"), veh.lineRef),
        vehicleRef: veh.formattedVehicleRef,
        distance: veh.distanceFromUserLocation(userLocation))
    } else {
      subView = UIView()
    }
    
    log.debug("subView at index \(indexPath): \(subView)")
    return subView  //TODO: return optional
  }
  
  func horizontalScrollerNoDataView(horizontalScroller: HorizontalScroller) -> UIView {
    let noDataView = VehicleHeaderView(
      lineRef: "",
      vehicleRef: NSLocalizedString("No busses near you", comment: "show as vehicle label when no busses near or no user location known"),
      distance: "")
    return noDataView
  }

  // MARK: - Notification functions
  func numberOfItemsInHorizontalScroller(horizontalScroller: HorizontalScroller) -> Int {
    let count = min(maxVisibleVehicleCount, vehicles.count)
    log.debug("numberOfItemsInHorizontalScroller: \(count)")
    return count
  }
  
  func horizontalScroller(horizontalScroller: HorizontalScroller, didScrollToViewAtIndex: Int) {
    log.verbose("horizontalScroller(_:didScrollToViewAtIndex: \(didScrollToViewAtIndex))")
    currentVehicleIndex = didScrollToViewAtIndex
    refreshStopsForCurrentVehicle(queue: nil) {_ in Async.main {self.progressViewManager.hideProgress()} }
  }
  
  func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller) {
    stopTableView.scrollToTop(animated: true)
    resetVehicleScrollView()
  }
  
  func horizontalScrollerTapped(horizontalScroller: HorizontalScroller) {
    stopTableView.scrollToTop(animated: true)
    resetVehicleScrollView()
  }
}