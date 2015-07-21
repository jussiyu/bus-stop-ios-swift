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
  @IBOutlet weak var vehicleStopTableView: UITableView!
  @IBOutlet weak var vehicleScrollView: HorizontalScroller!
  @IBOutlet weak var vehicleScrollViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var vehicleScrollViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var refreshToggle: UIBarButtonItem!
  @IBOutlet weak var progressLabel: UILabel!
  
  let progressViewManager = MediumProgressViewManager.sharedInstance
  let reachability = Reachability.reachabilityForInternetConnection()
  
  // MARK: - properties
  var currentVehicleIndex = 0
  let kCellIdentifier: String = "VehicleStopCell"
  var autoRefresh:Bool = false
  var autoRefreshTimer: NSTimer?
  
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
  private var userLoc: CLLocation?
  
  lazy private var api: APIController = {
    
    class APIDelegateBase: APIControllerProtocol {
      let ref: MainViewController
      init(ref: MainViewController) {
        self.ref = ref
      }

      func didReceiveAPIResults(results: JSON, next: AnyObject? -> Void) {
      }
      
      func didReceiveError(urlerror: NSError, next: AnyObject? -> Void) {
        self.ref.initialRefreshTaskQueue.removeAll()
        next(nil)
      }
      
      func handleError(results: JSON, next: AnyObject? -> Void) {
        Async.main {
          let errorTitle = results["data"]["title"] ?? "unknown error"
          let errorMessage = results["data"]["message"] ?? "unknown details"
          let alertController = UIAlertController(title: "Network error", message:
            "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
          alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
          self.ref.presentViewController(alertController, animated: true, completion: nil)
          self.ref.initialRefreshTaskQueue.removeAll()
          next(nil)
        }
      }
    }
    
    class VehicleDelegate :APIDelegateBase {
      override func didReceiveAPIResults(results: JSON, next: AnyObject? -> Void) {
        if results["status"] == "success" {
          Async.background {
            self.ref.vehicles = Vehicles(fromJSON: results["body"])
            next(nil)
          }
        } else { // status != success
          handleError(results, next: next)
        }
      }
      
    }

    class VehicleStopsDelegate :APIDelegateBase {
      override func didReceiveAPIResults(results: JSON, next: AnyObject? -> Void) {
        if results["status"] == "success" {
          Async.background {
            self.ref.vehicles.setStopsFromJSON(results["body"])
          }.main {
            self.ref.vehicleStopTableView.reloadData()
            self.ref.vehicleStopTableView.hidden = false
            self.ref.hideProgressLabel()
            self.ref.progressViewManager.hideProgress()
          }
        } else { // status != success
          handleError(results, next: next)
        }
      }
      
    }
    
    class StopsDelegate: APIDelegateBase {
      
      override func didReceiveAPIResults(results: JSON, next: AnyObject? -> Void) {
        if results["status"] == "success" {
          Async.background {
            self.ref.stops = Stop.StopsFromJSON(results["body"])
            next(nil)
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
      self.refreshStops(next)
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
      //      self.api.getVehicleActivityStopsForVehicle("")
      self.vehicleScrollView.reloadData()
    }
    
    q.tasks +=~ {
      log.info("load stops for the current vehicle")
      self.refreshStopsForCurrentVehicle()
    }
    
    q.tasks +=! {
      self.extendProgressLabelTextWith(NSLocalizedString("All data loaded", comment: ""))
      log.info("Task: show closest vehicle headers => load stops for the current vehicle")
      self.hideProgressLabel()
    }
    
    return q
  }()

  
  
  
  // MARK: - lifecycle
  override func viewDidLayoutSubviews() {
  }

  override func viewDidAppear(animated: Bool) {
    log.verbose("Initial refresh")
//    refreshVehicles()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    vehicleScrollView.delegate = self
    
    // Autorefresh
    autoRefresh = (refreshToggle.customView as! UISwitch).on

    // Reachability
    reachability.whenReachable = { reachability in
      self.extendProgressLabelTextWith(NSLocalizedString("Network connectivity resumed. Refreshing data from network...", comment: ""))

      log.debug("Now reachable")
      if self.stops.count == 0 {
        // Do successful refresh done earlier
        self.refreshVehicles()
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
  @IBAction func refreshToggled(sender: AnyObject) {
    if let toggle = refreshToggle.customView as? UISwitch {
      autoRefresh = toggle.on
      initAutoRefreshTimer(andFire: true)
    }
  }

  // MARK: - utility functions
  
  private func refreshStops(next: AnyObject? -> Void) {
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
      (refreshToggle.customView as! UISwitch).on = false
      let alert = UIAlertController(title: NSLocalizedString("Cannot connect to network", comment:""), message: NSLocalizedString("Please check that you have network connection.", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
      alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.Default, handler: nil))
      presentViewController(alert, animated: true, completion: nil)
    }
    
  }

  private func initAutoRefreshTimer(andFire: Bool = false) {
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

  private func refreshVehicles(next: AnyObject? -> Void = {_ in 0}) {
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

  private func refreshStopsForCurrentVehicle() {
    log.verbose("refreshStopsForVehicle")
    if let currentVehicleRef = currentVehicle?.vehRef {
      api.getVehicleActivityStopsForVehicle(currentVehicleRef, next: {_ in 0})
    }
  }
  
  func timedRefreshRequested(timer: NSTimer) {
    refreshVehicles()
  }
  
  func extendProgressLabelTextWith(text: String) {
    if progressLabel.text == nil || progressLabel.text!.isEmpty {
      progressLabel.text = text
    } else {
      progressLabel.text! += "\n\(text)"
    }
  }

  func hideProgressLabel() {
    UIView.animateWithDuration( 0.5, animations: {self.progressLabel.alpha = 0},
      completion: {(_) in self.progressLabel.hidden=true})
  }

}

// MARK: - UITableViewDataSource
extension MainViewController: UITableViewDataSource {
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return currentVehicle?.stops.count ?? 0
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier, forIndexPath:indexPath) as! UITableViewCell
    
    let currentVehicle = self.currentVehicle
    if currentVehicle != nil {
      if let lastPath = currentVehicle?.stops[indexPath.item].lastPathComponent, stop = stops[lastPath] {
        cell.textLabel?.text = "\(stop.name) (\(stop.id))"
      } else {
        cell.textLabel?.text = "Unknown stop (\(currentVehicle?.stops[indexPath.item].lastPathComponent))"
      }
    } else {
    }
    
    return cell
  }
  
}

// MARK: - UITableViewDelegate
extension MainViewController: UITableViewDelegate {
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    log.verbose("vehicleScrollView:didSelectRowAtIndexPath: \(indexPath.item)")
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
  
  func resetVehicleScrollView() {
    for viewIndex in 0..<vehicleScrollView.viewCount {
      if let view = vehicleScrollView.viewAtIndex(viewIndex) as? VehicleHeaderView {
        view.alpha = 1
        view.transform = CGAffineTransformIdentity
        view.fadeOutByOffset(0)
      }
    }
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
      lineRef: NSLocalizedString("no busses near you", comment: "show as vehicle label when no busses near or no user location known"),
      vehicleRef: "",
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
    vehicleStopTableView.reloadData()
  }
  
  func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller) {
    // User dragged vehicle header so scroll the stop table to top
    vehicleStopTableView.scrollToRowAtIndexPath(NSIndexPath(indexes: [0,0], length: 2), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
    resetVehicleScrollView()
  }
  
  func horizontalScrollerTapped(horizontalScroller: HorizontalScroller) {
    vehicleStopTableView.scrollToRowAtIndexPath(NSIndexPath(indexes: [0,0], length: 2), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
    resetVehicleScrollView()
  }
}