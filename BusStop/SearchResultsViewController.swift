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

struct WeakContainer<T where T: AnyObject> {
  weak var value : T?
  
  init (_ value: T) {
    self.value = value
  }
  
  func get() -> T? {
    return value
  }
}

// MARK: - UIViewController
class SearchResultsViewController: UIViewController {
  
  // MARK: - properties
//  @IBOutlet weak var lineLabel: UILabel!
//  @IBOutlet weak var vehicleLabel: UILabel!
//  @IBOutlet weak var vehicleDistanceLabel: UILabel!
  @IBOutlet var vehicleTableView: UITableView!
  @IBOutlet weak var refreshToggle: UIBarButtonItem!
  
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var vehicleHeaderView: UIView!
  var vehicleHeaderViews = Array<WeakContainer<UIView>>()
  
  var lineVehicles = LineVehicles()
  
  private var stops = [String: Stop]()
  private var userLoc: CLLocation?
  var closestVehicle: VehicleActivity? {
    if userLoc != nil {
      //      println("Getting closest vehicle")
      return lineVehicles.getClosestVehicle(userLoc!)
    } else {
      //      println("Getting first vehicle")
      return lineVehicles.getFirstVehicle()
    }
  }
  
  var closestVehicles: [VehicleActivity] {
    if userLoc != nil {
      //      println("Getting closest vehicle")
//      return lineVehicles.getClosestVehicles(userLoc!)
      return lineVehicles.getClosestVehicles(userLoc!)
    } else if let firstVeh = lineVehicles.getFirstVehicle() {
      //      println("Getting first vehicle")
      return [firstVeh]
    } else {
      return []
    }
  }
  
  var imageCache = [String:UIImage]()
  let kCellIdentifier: String = "SearchResultCell"
  
  var autoRefresh:Bool = false
  
  var autoRefreshTimer: NSTimer?
  
  lazy private var api: APIController = {
    
    class VehicleDelegate: APIControllerProtocol {
      let ref: SearchResultsViewController
      init(ref: SearchResultsViewController) {
        self.ref = ref
      }
      func didReceiveAPIResults(results: JSON) {
        dispatch_async(dispatch_get_main_queue(), {
          if results["status"] == "success" {
            self.ref.lineVehicles = LineVehicles(fromJSON: results["body"])
            if let userLoc = self.ref.userLoc where self.ref.closestVehicles.count > 0 {
              for var i = 0; i < 10 && i < self.ref.closestVehicles.count; ++i {
                let veh = self.ref.closestVehicles[i]
//                self.ref.lineLabel.text = String(format: NSLocalizedString("Line %@", comment: "Line name header"), closestVehicle.lineRef)
//                self.ref.vehicleLabel.text = closestVehicle.getFormattedVehicleRef()
//                self.ref.vehicleDistanceLabel.text = closestVehicle.getDistanceFromUserLocation(userLoc)
                self.ref.setVehicleLabelsForIndex(i,
                  lineRef: String(format: NSLocalizedString("Line %@", comment: "Line name header"), veh.lineRef),
                  vehicleRef: veh.getFormattedVehicleRef(),
                  distance: veh.getDistanceFromUserLocation(userLoc))
              }
            } else {
              self.ref.setVehicleLabelsForIndex(0, lineRef: NSLocalizedString("no busses near you", comment: "show as vehicle label when no busses near or no user location known"),
                  vehicleRef: "",
                  distance: "")
            }
            self.ref.vehicleTableView!.reloadData()
          } else {
            let errorTitle = results["data"]["title"] ?? "unknown error"
            let errorMessage = results["data"]["message"] ?? "unknown details"
            let alertController = UIAlertController(title: "Network error", message:
              "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.ref.presentViewController(alertController, animated: true, completion: nil)
          }
        })
      }
    }
    
    class StopsDelegate: APIControllerProtocol {
      let ref: SearchResultsViewController
      init(ref: SearchResultsViewController) {
        self.ref = ref
      }
      func didReceiveAPIResults(results: JSON) {
        dispatch_async(dispatch_get_main_queue(), {
          if results["status"] == "success" {
            self.ref.stops = Stop.StopsFromJSON(results["body"])
          } else {
            let errorTitle = results["data"]["title"] ?? "unknown error"
            let errorMessage = results["data"]["message"] ?? "unknown details"
            let alertController = UIAlertController(title: "Network error", message:
              "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.ref.presentViewController(alertController, animated: true, completion: nil)
          }
          
          // Load initial vehicle data after stops have been read
          self.ref.doLoadVehicleData()
        })
      }
    }
    
    return APIController(vehDelegate: VehicleDelegate(ref: self), stopsDelegate: StopsDelegate(ref: self))
    }()
  
  // MARK: - lifecycle
  override func viewDidLayoutSubviews() {
//    let nextVehicleHeaderView = vehicleHeaderView.snapshotViewAfterScreenUpdates(true)
//    if let label = nextVehicleHeaderView.subviews[0] as? UIView {
//      println("tag: \(label.tag)")
////      label.text = "Hello"
//    }
//    nextVehicleHeaderView.center.x += 200
//    scrollView.addSubview(nextVehicleHeaderView)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast
//    scrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
    
    vehicleHeaderViews.append(WeakContainer(vehicleHeaderView))
    let tempArchive = NSKeyedArchiver.archivedDataWithRootObject(vehicleHeaderView)
    for i in 1...9 {
      let nextVehicleHeaderView = NSKeyedUnarchiver.unarchiveObjectWithData(tempArchive) as! UIView
      vehicleHeaderViews.append(WeakContainer(nextVehicleHeaderView))
      
      scrollView.addSubview(nextVehicleHeaderView)
//      nextVehicleHeaderView.setTranslatesAutoresizingMaskIntoConstraints(false);
      
      let offsetConstraint = NSLayoutConstraint(item: nextVehicleHeaderView, attribute: .Leading, relatedBy: .Equal,
        toItem: vehicleHeaderViews[i - 1].value, attribute: NSLayoutAttribute.Right, multiplier: 1, constant: 10)
      offsetConstraint.active = true
      let topConstraint = NSLayoutConstraint(item: nextVehicleHeaderView, attribute: .Top, relatedBy: .Equal, toItem: nextVehicleHeaderView.superview, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0)
      topConstraint.active = true
      
//      println("vehicleHeader frame1: \(vehicleHeaderView.frame), frame2: \(nextVehicleHeaderView.frame)")
//      println("vehicleHeader bounds1: \(vehicleHeaderView.bounds), bounds2: \(nextVehicleHeaderView.bounds)")
    }
//    scrollView.bounds.size.width = 10000
    println("scrollView bounds: \(scrollView.bounds), frame: \(scrollView.frame), contentsize: \(scrollView.contentSize)")

    NSNotificationCenter.defaultCenter().addObserver(self, selector: "locationUpdated:", name: "newLocationNotif", object: nil)
    
    if let toggle = refreshToggle.customView as? UISwitch {
      autoRefresh = toggle.on
    }
    
    initAutoRefreshTimer()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - actions
  @IBAction func refreshToggled(sender: AnyObject) {
    if let toggle = refreshToggle.customView as? UISwitch {
      autoRefresh = toggle.on
      if autoRefresh {
        initAutoRefreshTimer()
        println("Refresh enabled")
      } else {
        println("Refresh disabled")
        autoRefreshTimer?.invalidate()
      }
    }
  }

  @IBAction func inputFieldChanged(sender: AnyObject) {
    doLoadVehicleData()
  }
  
  // MARK: - utility functions
  private func initAutoRefreshTimer() {
    autoRefreshTimer?.invalidate()
    if autoRefresh {
      autoRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "timedRefreshRequested:", userInfo: nil, repeats: true)
      //      autoRefreshTimer?.tolerance =
      autoRefreshTimer?.fire()
    } else {
      println("Intial reload")
      api.getStops()
    }
  }
  
  private func setVehicleLabelsForIndex(index: Int, lineRef: String, vehicleRef: String, distance: String) {
    if index < vehicleHeaderViews.count {
      if let vehView = vehicleHeaderViews[index].value {
        if let label = vehView.viewWithTag(1) as? UILabel {
          label.text = lineRef
        }
        if let label = vehView.viewWithTag(2) as? UILabel {
          label.text = vehicleRef
        }
        if let label = vehView.viewWithTag(3) as? UILabel {
          label.text = distance.stringByReplacingOccurrencesOfString("\\n", withString: "\n", options: nil)
        }
      }
    }
  }
  
  
  func doLoadVehicleData() {
    var lineId = 1
    api.getVehicleActivitiesForLine(lineId)
  }
  
  func timedRefreshRequested(timer: NSTimer) {
    println("Refresh requested1")
    api.getStops()
  }
  
}

// MARK: - UITableViewDataSource
extension SearchResultsViewController: UITableViewDataSource {
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if closestVehicle != nil {
      return closestVehicle!.stops.count
    } else {
      return 0
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier, forIndexPath:indexPath) as! UITableViewCell
    
    if closestVehicle != nil {
      if let lastPath = closestVehicle!.stops[indexPath.item].lastPathComponent, stop = stops[lastPath] {
        cell.textLabel?.text = stop.name
        cell.detailTextLabel?.text = stop.id
      } else {
        cell.textLabel?.text = closestVehicle!.stops[indexPath.item].lastPathComponent
        cell.detailTextLabel?.text = "unknown stop"
      }
    } else {
    }
    
    return cell
  }
  
}

// MARK: - UITableViewDelegate
extension SearchResultsViewController: UITableViewDelegate {
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    //    // Get the row data for the selected row
    //    if let rowData = self.vehicleData[indexPath.row] as? NSDictionary,
    //      // Get the name of the track for this row
    //      name = rowData["trackName"] as? String,
    //      // Get the price of the track on this row
    //      formattedPrice = rowData["formattedPrice"] as? String {
    //        let alert = UIAlertController(title: name, message: formattedPrice, preferredStyle: .Alert)
    //        alert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
    //        self.presentViewController(alert, animated: true, completion: nil)
    //    }
  }
}


// MARK: - UITextFieldDelegate
extension SearchResultsViewController: UITextFieldDelegate {
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - UIPickerViewDataSource
extension SearchResultsViewController: UIPickerViewDataSource {
  func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    switch component {
    case 0:
      return 20
    case 1:
      return lineVehicles.count + 1
    default:
      return 0
    }
  }
  
  func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
    return 2
  }
}

//
////MARK: - APIControllerProtocol
//extension SearchResultsViewController: APIControllerProtocol {
//  func didReceiveAPIResults(results: JSON) {
//    dispatch_async(dispatch_get_main_queue(), {
//      self.lineVehicles = LineVehicles(fromJSON: results["body"])
//      self.vehicleTableView!.reloadData()
//    })
//  }
//}
//

// MARK: - locationUpdate notification handler
extension SearchResultsViewController {
  @objc func locationUpdated(notification: NSNotification){
    println("locationUpdate \(notification.name)")
    if let loc = notification.userInfo as? [String:CLLocation] {
      userLoc = loc["newLocationResult"]
      println("new user loc:  \(userLoc?.description)")
      vehicleTableView.reloadData()
    }
  }
}

// MARK: - UIScrollViewDelegate
extension SearchResultsViewController: UIScrollViewDelegate {
  
  func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    
    var pageWidth = Float(200 + 10)
    var currentOffset = Float(scrollView.contentOffset.x)
    var targetOffset = Float(targetContentOffset.memory.x)
    var newTargetOffset = Float(0)
    var scrollViewWidth = Float(scrollView.contentSize.width)
    
    if targetOffset > currentOffset {
      newTargetOffset = ceilf(currentOffset / pageWidth) * pageWidth
    } else {
      newTargetOffset = floorf(currentOffset / pageWidth) * pageWidth
    }
    
    if newTargetOffset < 0 {
      newTargetOffset = 0
    } else if newTargetOffset > currentOffset {
      newTargetOffset = currentOffset
    }
    
    Float(targetContentOffset.memory.x) == currentOffset
    
    scrollView.setContentOffset(CGPointMake(CGFloat(newTargetOffset), 0), animated: true)
  
//    let currentOffset = scrollView.contentOffset
//    var newOffset = CGPointZero
//    
//    if let lastScrollOffset = lastScrollOffset {
//      println("scrollView offsets: last: \(lastScrollOffset.x), current: \(currentOffset.x)")
//      if lastScrollOffset.x < currentOffset.x {
//        newOffset.x = lastScrollOffset.x + 298
//      } else {
//        newOffset.x = lastScrollOffset.x - 298
//      }
//    }
//
//    UIView.animateWithDuration(0.4) { targetContentOffset.memory = newOffset}
  }
}