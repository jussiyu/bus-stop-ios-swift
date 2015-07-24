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
  var vehicles = Vehicles()
  var closestVehicles: [VehicleActivity] {
    if userLoc != nil {
      //      log.verbose("Getting closest vehicle")
      //      return lineVehicles.getClosestVehicles(userLoc!)
      return vehicles.getClosestVehicles(userLoc!)
    } else if let firstVeh = vehicles.getFirstVehicle() {
      //      log.verbose("Getting first vehicle")
      return [firstVeh]
    } else {
      return []
    }
  }
  var currentVehicle: VehicleActivity? {
    let closestVehicles = self.closestVehicles
    if closestVehicles.count > currentVehicleIndex {
      return closestVehicles[currentVehicleIndex]
    } else {
      return nil
    }
  }

  private var stops = [String: Stop]()

  private var currentVehicleIndex = 0 {
    didSet {
      selectedStop = nil
    }
  }
  private var selectedStop: Stop?
  private var userLoc: CLLocation?
  
  lazy private var api: APIController = {
    
    class APIDelegateBase: APIControllerProtocol {
      let ref: MainViewController
      init(ref: MainViewController) {
        self.ref = ref
      }

      func didReceiveAPIResults(results: JSON, next: APIController.NextTask?) {
      }
      
      func didReceiveError(urlerror: NSError, next: APIController.NextTask?) {
        self.ref.initialRefreshTaskQueue.removeAll()
        next?(nil)
      }
      
      func handleError(results: JSON, next: APIController.NextTask?) {
        Async.main {
          let errorTitle = results["data"]["title"] ?? "unknown error"
          let errorMessage = results["data"]["message"] ?? "unknown details"
          let alertController = UIAlertController(title: "Network error", message:
            "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
          alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
          self.ref.presentViewController(alertController, animated: true, completion: nil)
          self.ref.initialRefreshTaskQueue.removeAll()
          next?(nil)
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
          }.main {
            self.ref.stopTableView.reloadData()
            
            if self.ref.selectedStop != nil && self.ref.rowForStop(self.ref.selectedStop!) == nil {
              log.debug("Selected stop passed")
              if let queue = self.ref.autoUnexpandTaskQueue where !queue.running {
                log.debug("Launching auto unexpand")
                queue.run()
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

  lazy var initialRefreshTaskQueue: TaskQueue = {
    let q = TaskQueue()
    
    q.tasks +=! {
      log.info("Task: show progress")
      self.progressViewManager.showProgress()
    }
    
    q.tasks +=~ { result, next in
      log.info("Task: load stop data")
      self.extendProgressLabelTextWith(NSLocalizedString("Refreshing stop information from network...", comment: ""))
      self.refreshStops(next: next)
    }
    
    q.tasks +=~ { result, next in
      log.info("Task: load vehicle headers")
      self.extendProgressLabelTextWith(NSLocalizedString("Refreshing bus information from network...", comment: ""))
      self.refreshVehicles(next: next)
    }

    q.tasks +=! {
      self.extendProgressLabelTextWith(NSLocalizedString("Bus data loaded.", comment: ""))
    }
    
    q.tasks +=~ {[weak q] result, next in
      log.info("Task: wait for location")
      // get closes vehicle
      if self.userLoc == nil {
        q!.retry(delay: 0.5)
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
      self.refreshStopsForCurrentVehicle(next: next)
    }
    
    q.tasks +=! {
      log.info("Task: show closest vehicle headers => load stops for the current vehicle")
      self.stopTableView.hidden = false
      self.extendProgressLabelTextWith(NSLocalizedString("All data loaded", comment: ""))
      self.hideProgressLabel()
    }
    
    return q
  }()

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
    
    // Reachability
    reachability.whenReachable = { reachability in
      self.extendProgressLabelTextWith(NSLocalizedString("Network connectivity resumed. Refreshing data from network...", comment: ""))

      log.debug("Now reachable")
      if self.stops.count == 0 {
        self.initialRefreshTaskQueue.run {
          self.progressViewManager.hideProgress()
          log.info("Intial refresh done successfully!")
        }
      }
    }
    reachability.startNotifier()

    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "preferredContentSizeChanged:",
      name: UIContentSizeCategoryDidChangeNotification,
      object: nil)

    initialRefreshTaskQueue.run {
      self.progressViewManager.hideProgress()
      log.info("Intial refresh done successfully!")
    }
  }

  override func viewWillAppear(animated: Bool) {
    extendProgressLabelTextWith(NSLocalizedString("Aquiring location...", comment: ""))
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "locationUpdated:", name: "newLocationNotif", object: nil)
  }

  override func viewWillDisappear(animated: Bool) {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
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
  
  private func refreshStops(#next: APIController.NextTask?) {
    log.verbose("RefreshStops")
    
    if reachability.isReachable() {
      if reachability.isReachableViaWiFi() {
        log.debug("Reachable via WiFi")
      } else {
        log.debug("Reachable via Cellular")
      }
      api.getStops(next)
    } else {
      log.debug("Not reachable")
      progressViewManager.hideProgress()
      
      // Disable autorefresh
      (autoRefreshSwitch.customView as! UISwitch).on = false
      let alert = UIAlertController(title: NSLocalizedString("Cannot connect to network", comment:""), message: NSLocalizedString("Please check that you have network connection.", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
      alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.Default, handler: nil))
      presentViewController(alert, animated: true, completion: nil)
    }
  }

  private func refreshVehicles(#next: APIController.NextTask?) {
    log.verbose("RefreshVehicles")
    
    if reachability.isReachable() {
      if reachability.isReachableViaWiFi() {
        log.debug("Reachable via WiFi")
      } else {
        log.debug("Reachable via Cellular")
      }
      api.getVehicleActivityHeaders(next: next)
    } else {
      log.debug("Not reachable")
      progressViewManager.hideProgress()
    }
  }

  private func refreshStopsForCurrentVehicle(#next: APIController.NextTask?) {
    log.verbose("refreshStopsForVehicle")
    if let currentVehicleRef = currentVehicle?.vehRef {
      api.getVehicleActivityStopsForVehicle(currentVehicleRef, next: next)
    } else {
      log.warning("no current vehicle found")
      next?(nil)
    }
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
    refreshStopsForCurrentVehicle { _ in Async.main {self.progressViewManager.hideProgress()} }
  }
  
  func extendProgressLabelTextWith(text: String) {
    if progressLabel.text == nil || progressLabel.text!.isEmpty {
      progressLabel.text = text
    } else {
      progressLabel.text! += "\n\(text)"
    }
  }

  func hideProgressLabel() {
    UIView.animateWithDuration( 0.3, animations: {self.progressLabel.alpha = 0},
      completion: {(_) in self.progressLabel.hidden=true})
  }

  
  func stopForRow(row: Int) -> Stop? {
    // TODO check row overflow?
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
      return nil
    }
  }
}

// MARK: - UITableViewDataSource
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
          cell.textLabel?.text = "Unknown stop"
          log.error("Unknown stop")
        }
      }
  
      return cell
      
    } else { // selectedStop != nil
      
      // selected cell
      let cell = tableView.dequeueReusableCellWithIdentifier(selectedCellIdentifier, forIndexPath:indexPath) as! SelectedStopTableViewCell
      
      let currentVehicle = self.currentVehicle
      // Return the currently selected stop
      cell.stopNameLabel.text = "\(selectedStop!.name)\n(\(selectedStop!.id))"
      let stopNameLabelFont = UIFont(descriptor: UIFontDescriptor.preferredDescriptorWithStyle(UIFontTextStyleHeadline, oversizedBy: 16), size: 0)
      cell.stopNameLabel.font = stopNameLabelFont
      
      if let ref = selectedStop!.ref {
        if let stopsBeforeSelectedStop = currentVehicle?.stopIndexByRef(ref) {
          cell.distanceHintLabel.text = String(format: NSLocalizedString("%d stop(s) before your stop", comment: ""), stopsBeforeSelectedStop)
        } else {
          cell.distanceHintLabel.text = autoUnexpandTaskQueueProgress ?? ""
        }
      }
    
      return cell
    }
  }
  
}

// MARK: - UITableViewDelegate
extension MainViewController: UITableViewDelegate {
  
  func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//    let header = UIView()
    stopTableViewHeader = UILabel()
    if selectedStop == nil {
      stopTableViewHeader!.text = NSLocalizedString("Choose your stop", comment: "")
    } else {
      stopTableViewHeader!.text = NSLocalizedString("Now tracking your stop", comment: "")
    }
    stopTableViewHeader!.textAlignment = .Center
    stopTableViewHeader!.backgroundColor = UIColor.whiteColor()
//    let blurEffect = UIBlurEffect(style: .Light)
//    let blurView = UIVisualEffectView(effect: blurEffect)
//    blurView.setTranslatesAutoresizingMaskIntoConstraints(false)
//    labelView.setTranslatesAutoresizingMaskIntoConstraints(false)
//    header.addSubview(blurView)
//    header.addSubview(labelView)
//    NSLayoutConstraint.constraintsWithVisualFormat("V:|[v]|", views: ["v":blurView], active: true)
//    NSLayoutConstraint.constraintsWithVisualFormat("H:|[v]|", views: ["v":blurView], active: true)
//    NSLayoutConstraint.constraintsWithVisualFormat("V:|[v]|", views: ["v":labelView], active: true)
//    NSLayoutConstraint.constraintsWithVisualFormat("H:|[v]|", views: ["v":labelView], active: true)
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
      
      // Use the positive value of the table scroll offset to animate other views
      let offset = max(scrollView.contentOffset.y, 0)
      //    log.debug("vehicleScrollView vertical offset: \(offset)")
      
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
    } else {
      if let currentVehicleHeaderView = vehicleScrollView.viewAtIndex(currentVehicleIndex) {
        currentVehicleHeaderView.alpha = 1
        currentVehicleHeaderView.transform = CGAffineTransformIdentity
      }
    }
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
  
  private func unexpandSelectedStop() {
    autoUnexpandTaskQueue?.cancel()
    autoUnexpandTaskQueue = initAutoUnexpandTaskQueue()

    stopTableView.deselectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), animated: true)
    // the tapped (and only) row was already selected => add other rows back
    
    // calculate the final row for the selected stop (or nil)
    var newRowForSelectedStop = rowForStop(selectedStop!)
    
    // reset the selection
    selectedStop = nil
    
    // pick all the rows but the currently selected one (assume moved to the new row)
    var indexPathsOnAbove = [NSIndexPath]()
    if let rowForSelectedStop = newRowForSelectedStop {
      for row in 0 ..< rowForSelectedStop {
        let indexPath = NSIndexPath(forRow: row, inSection: 0)
        indexPathsOnAbove.append(indexPath)
      }
    }
    
    var indexPathsOnBelow = [NSIndexPath]()
    let rowCount = currentVehicle?.stops.count ?? 0
    if newRowForSelectedStop == nil {
      // row for selected stop does not exist anymore so add all rows as "below-rows"
      newRowForSelectedStop = -1
    }
    if newRowForSelectedStop! + 1 < rowCount {
      for row in (newRowForSelectedStop! + 1) ..< rowCount {
        let indexPath = NSIndexPath(forRow: row, inSection: 0)
        indexPathsOnBelow.append(indexPath)
      }
    }

    // Reset the size of the table view
    stopTableView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
    
    // perform the correct update operation
    stopTableView.beginUpdates()

    if let header = stopTableViewHeader {
      header.text = NSLocalizedString("Select your stop", comment: "")
    }

    // decide what to do with the current row (on row #0)
    let currentSelectedRowIndexPath = NSIndexPath(forRow: 0, inSection: 0)
    if let newRowForSelectedStop = newRowForSelectedStop where newRowForSelectedStop >= 0 {
      // the selected row will exist on the same row (#0) in the restored list so update it
      if newRowForSelectedStop == 0 {
        stopTableView.reloadRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .Fade)
      } else {
        // the selected row will exist on a new row in the restored list so move it
//        stopTableView.moveRowAtIndexPath(currentSelectedRowIndexPath, toIndexPath: NSIndexPath(forRow: newRowForSelectedStop, inSection: 0))
        stopTableView.reloadRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .None)
      }
    } else {
      // row does not exist anymore so delete it
      stopTableView.deleteRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .Fade)
    }

    // safe to forget now which row was selected
    stopTableView.insertRowsAtIndexPaths(indexPathsOnAbove, withRowAnimation: UITableViewRowAnimation.Top)
    stopTableView.insertRowsAtIndexPaths(indexPathsOnBelow, withRowAnimation: UITableViewRowAnimation.Bottom)
    
    autoRefresh = false
    
    stopTableView.endUpdates()

    initAutoRefreshTimer()

  }
  
  private func expandStopAtIndexPath(indexPath: NSIndexPath) {
    stopTableView.deselectRowAtIndexPath(indexPath, animated: true)
    
    // no row was selected when the row was tapped => remove other rows
    
    // store the stop for the selected row
    selectedStop = stopForRow(indexPath.row)
    
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
    
    // perform the correct update operation
    stopTableView.beginUpdates()
    if let header = stopTableViewHeader {
      header.text = NSLocalizedString("Stop selected", comment: "")
    }
    stopTableView.deleteRowsAtIndexPaths(indexPathsOnAbove, withRowAnimation: .Top)
    stopTableView.deleteRowsAtIndexPaths(indexPathsOnBelow, withRowAnimation: .Bottom)
    
    // Maximize the table view
    if let currentVehicleHeaderView = vehicleScrollView.viewAtIndex(currentVehicleIndex) as? VehicleHeaderView {
      let maxOffset = currentVehicleHeaderView.bounds.height + currentVehicleHeaderView.layoutMargins.bottom
      stopTableView.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: false)
    }
    
    autoRefresh = true
    
    stopTableView.endUpdates()
    stopTableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Fade)
    
    initAutoRefreshTimer()

  }
}

// MARK: - UITextFieldDelegate
extension MainViewController: UITextFieldDelegate {
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - locationUpdate notification handler
extension MainViewController {
  @objc func locationUpdated(notification: NSNotification){
    log.verbose("locationUpdate \(notification.name)")
    if let locInfo = notification.userInfo as? [String:CLLocation], newLoc = locInfo["newLocationResult"] {
      if userLoc == nil || userLoc!.moreAccurateThanLocation(newLoc) ||
          !userLoc!.commonHorizontalLocationWith(newLoc) {
        userLoc = newLoc
        log.info("New user loc:  \(self.userLoc?.description)")
        extendProgressLabelTextWith(NSLocalizedString("Location acquired.", comment: ""))
//        vehicleStopTableView.reloadData()
      } else {
        log.info("Existing or worse user loc notified. Ignored.")
      }
    }
  }
}

// MARK: - preferredContentSizeChanged notification handler
extension MainViewController {
  func preferredContentSizeChanged(notification: NSNotification) {
    log.verbose("preferredContentSizeChanged")
    //    vehicleStopTableView takes care of itself
    vehicleScrollView.reloadData()
  }
}

// MARK: - HorizontalScrollerDelegate
extension MainViewController: HorizontalScrollerDelegate {
  
  // MARK: - Data source functions
  func horizontalScroller(horizontalScroller: HorizontalScroller, viewAtIndexPath indexPath: Int) -> UIView {
    let closestVehicles = self.closestVehicles
    var subView: UIView = UIView()
    if let userLoc = userLoc where closestVehicles.count > indexPath {
      let veh = closestVehicles[indexPath]
      subView = VehicleHeaderView(
        lineRef: String(format: NSLocalizedString("Line %@", comment: "Line name header"), veh.lineRef),
        vehicleRef: veh.formattedVehicleRef,
        distance: veh.distanceFromUserLocation(userLoc))
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
    refreshStopsForCurrentVehicle {_ in Async.main {self.progressViewManager.hideProgress()} }
  }
  
  func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller) {
    // User dragged vehicle header so scroll the stop table to top
    stopTableView.scrollToRowAtIndexPath(NSIndexPath(indexes: [0,0], length: 2), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
    resetVehicleScrollView()
  }
  
  func horizontalScrollerTapped(horizontalScroller: HorizontalScroller) {
    stopTableView.scrollToRowAtIndexPath(NSIndexPath(indexes: [0,0], length: 2), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
    resetVehicleScrollView()
  }
}