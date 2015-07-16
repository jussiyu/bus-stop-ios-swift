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

// MARK: - UIViewController
class MainViewController: UIViewController {
  
  // MARK: - outlets
  @IBOutlet weak var vehicleStopTableView: UITableView!
  @IBOutlet weak var vehicleScrollView: HorizontalScroller!
  @IBOutlet weak var vehicleScrollViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var vehicleScrollViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var refreshToggle: UIBarButtonItem!

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
      //      println("Getting closest vehicle")
      //      return lineVehicles.getClosestVehicles(userLoc!)
      return vehicles.getClosestVehicles(userLoc!)
    } else if let firstVeh = vehicles.getFirstVehicle() {
      //      println("Getting first vehicle")
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
//  var closestVehicle: VehicleActivity? {
//    if userLoc != nil {
//      //      println("Getting closest vehicle")
//      return vehicles.getClosestVehicle(userLoc!)
//    } else {
//      //      println("Getting first vehicle")
//      return vehicles.getFirstVehicle()
//    }
//  }
  
  lazy private var api: APIController = {
    
    class VehicleDelegate: APIControllerProtocol {
      let ref: MainViewController
      init(ref: MainViewController) {
        self.ref = ref
      }
      func didReceiveAPIResults(results: JSON) {
        if results["status"] == "success" {
          self.ref.vehicles = Vehicles(fromJSON: results["body"])
          dispatch_async(dispatch_get_main_queue(), {
            self.ref.vehicleScrollView.reloadData()
            self.ref.vehicleStopTableView.reloadData()
          })
          dispatch_async(dispatch_get_main_queue()) {self.ref.progressViewManager.hideProgress()}
        } else { // status != success
          dispatch_async(dispatch_get_main_queue(), {
            let errorTitle = results["data"]["title"] ?? "unknown error"
            let errorMessage = results["data"]["message"] ?? "unknown details"
            let alertController = UIAlertController(title: "Network error", message:
              "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.ref.presentViewController(alertController, animated: true, completion: nil)
            self.ref.progressViewManager.hideProgress()
          })
        }
      }
      
      func didReceiveError(urlerror: NSError) {
        dispatch_async(dispatch_get_main_queue(), {
          self.ref.progressViewManager.hideProgress()
        })
      }
    }
    
    class StopsDelegate: APIControllerProtocol {
      let ref: MainViewController
      init(ref: MainViewController) {
        self.ref = ref
      }
      func didReceiveAPIResults(results: JSON) {
        if results["status"] == "success" {
          self.ref.stops = Stop.StopsFromJSON(results["body"])
          // Load initial vehicle data after stops have been read
          self.ref.api.getVehicleActivities()
        } else {
          dispatch_async(dispatch_get_main_queue(), {
            let errorTitle = results["data"]["title"] ?? "unknown error"
            let errorMessage = results["data"]["message"] ?? "unknown details"
            let alertController = UIAlertController(title: "Network error", message:
              "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.ref.presentViewController(alertController, animated: true, completion: nil)
            self.ref.progressViewManager.hideProgress()
          })
        }
      }

      func didReceiveError(urlerror: NSError) {
        self.ref.progressViewManager.hideProgress()
      }
    }
    
    return APIController(vehDelegate: VehicleDelegate(ref: self), stopsDelegate: StopsDelegate(ref: self))
  }()
  
  // MARK: - lifecycle
  override func viewDidLayoutSubviews() {
  }

  override func viewDidAppear(animated: Bool) {
    println("Initial refresh")
    refreshVehicles()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    vehicleScrollView.delegate = self
//    scrollView.reload()
    
    // Autorefresh
    autoRefresh = (refreshToggle.customView as! UISwitch).on

    // Reachability
    reachability.whenReachable = { reachability in
      println("Now reachable")
      if self.stops.count == 0 {
        // Do successful refresh done earlier
        self.refreshVehicles()
      }
    }
    reachability.startNotifier()

    initAutoRefreshTimer()

    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "preferredContentSizeChanged:",
      name: UIContentSizeCategoryDidChangeNotification,
      object: nil)
  }

  override func viewWillAppear(animated: Bool) {
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
  
  private func initAutoRefreshTimer(andFire: Bool = false) {
    autoRefreshTimer?.invalidate()
    if autoRefresh {
      autoRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "timedRefreshRequested:", userInfo: nil, repeats: true)
      if andFire {autoRefreshTimer?.fire()}
      autoRefreshTimer?.tolerance = 2
      println("Refresh enabled")
    } else {
      println("Refresh disabled")
    }
  }

  
  private func refreshVehicles() {
    println("RefreshVehicles")
    progressViewManager.showProgress()
    
    if reachability.isReachable() {
      if reachability.isReachableViaWiFi() {
        println("Reachable via WiFi")
      } else {
        println("Reachable via Cellular")
      }
      if stops.count == 0 {
        api.getStops()
      } else {
        api.getVehicleActivities()
      }
    } else {
      println("Not reachable")
      progressViewManager.hideProgress()
      
      // Disable autorefresh
      (refreshToggle.customView as! UISwitch).on = false
      let alert = UIAlertController(title: NSLocalizedString("Cannot connect to network", comment:""), message: NSLocalizedString("Please check that you have network connection.", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
      alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.Default, handler: nil))
      presentViewController(alert, animated: true, completion: nil)
    }

  }
  
  func timedRefreshRequested(timer: NSTimer) {
    refreshVehicles()
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
    println("vehicleScrollView:didSelectRowAtIndexPath: \(indexPath.item)")
  }
  
  func scrollViewDidScroll(scrollView: UIScrollView) {
    // Dim the vehicle scroller and move it up
    // Also slide adjacent headers to the side

    // Use the positive value of the table scroll offset to animate other views
    let offset = max(scrollView.contentOffset.y, 0)
//    println("vehicleScrollView vertical offset: \(offset)")
    
    // Offset the header view up by max of its height
    vehicleScrollViewTopConstraint.constant = -min(offset, vehicleScrollView.bounds.height +  NSLayoutConstraint.standardAquaSpaceConstraintFromItem) + NSLayoutConstraint.standardAquaSpaceConstraintFromItem

    vehicleScrollView.alpha = (vehicleScrollView.bounds.height - offset) / vehicleScrollView.bounds.height * 0.7

    // Scroll adjacent headers to side by making the current header wider and keeping it centered
    if let currentVehicleHeaderView = vehicleScrollView.viewAtIndex(currentVehicleIndex) as? VehicleHeaderView {
      currentVehicleHeaderView.widthExtra = offset
      currentVehicleHeaderView.invalidateIntrinsicContentSize()
      vehicleScrollView.layoutIfNeeded()
      vehicleScrollView.scrollToViewWithIndex(currentVehicleIndex, animated: false)
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
    println("locationUpdate \(notification.name)")
    if let loc = notification.userInfo as? [String:CLLocation] {
      userLoc = loc["newLocationResult"]
      println("new user loc:  \(userLoc?.description)")
      vehicleStopTableView.reloadData()
    }
  }
}

// MARK: - preferredContentSizeChanged notification handler
extension MainViewController {
  func preferredContentSizeChanged(notification: NSNotification) {
    println("preferredContentSizeChanged")
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
    
    println("subView at index \(indexPath): \(subView)")
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
    println("numberOfItemsInHorizontalScroller: \(count)")
    return count
  }
  
  func horizontalScroller(horizontalScroller: HorizontalScroller, didScrollToViewAtIndex: Int) {
    println("horizontalScroller(_:didScrollToViewAtIndex: \(didScrollToViewAtIndex))")
    currentVehicleIndex = didScrollToViewAtIndex
    vehicleStopTableView.reloadData()
  }
  
  func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller) {
    // User dragged vehicle header so scroll the stop table to top
    vehicleStopTableView.scrollToRowAtIndexPath(NSIndexPath(indexes: [0,0], length: 2), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
  }
}