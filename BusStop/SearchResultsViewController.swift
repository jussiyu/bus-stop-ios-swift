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
import CircleProgressView

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
  
  // MARK: - outlets
  @IBOutlet weak var vehicleTableView: UITableView!
  @IBOutlet weak var refreshToggle: UIBarButtonItem!
  
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var vehicleHeaderView: UIView!
  @IBOutlet weak var progressView: CircleProgressView!

  // MARK: - properties
  var vehicleHeaderViews = Array<WeakContainer<UIView>>()
  var scrollViewPageWidth: CGFloat = 200 + 20
  let scrollVIewContentMargin: CGFloat = 10
  var vehicles = Vehicles()
  let maxVehicleCount = 10
  
  private var stops = [String: Stop]()
  private var userLoc: CLLocation?
  var closestVehicle: VehicleActivity? {
    if userLoc != nil {
      //      println("Getting closest vehicle")
      return vehicles.getClosestVehicle(userLoc!)
    } else {
      //      println("Getting first vehicle")
      return vehicles.getFirstVehicle()
    }
  }
  
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
          self.ref.progressView.progress = 0.6
          if results["status"] == "success" {
            self.ref.vehicles = Vehicles(fromJSON: results["body"])
            self.ref.progressView.progress = 0.9
            if let userLoc = self.ref.userLoc where self.ref.closestVehicles.count > 0 {
              for var i = 0; i < self.ref.maxVehicleCount; ++i {
                if i < self.ref.closestVehicles.count {
                  self.ref.vehicleHeaderViews[i].value?.hidden = false
                  let veh = self.ref.closestVehicles[i]
                  self.ref.setVehicleLabelsForIndex(i,
                    lineRef: String(format: NSLocalizedString("Line %@", comment: "Line name header"), veh.lineRef),
                    vehicleRef: veh.formattedVehicleRef,
                    distance: veh.distanceFromUserLocation(userLoc))
                } else {
                  self.ref.vehicleHeaderViews[i].value?.hidden = true
                }
              }
            } else {
              self.ref.setVehicleLabelsForIndex(0, lineRef: NSLocalizedString("no busses near you", comment: "show as vehicle label when no busses near or no user location known"),
                  vehicleRef: "",
                  distance: "")
              self.ref.vehicleHeaderViews[0].value?.hidden = false
            }
            self.ref.vehicleTableView!.reloadData()
            UIView.transitionWithView(self.ref.progressView,
              duration: 1, options: UIViewAnimationOptions.TransitionCrossDissolve,
              animations: {self.ref.progressView.alpha = 0}, completion: {(finished) in self.ref.progressView.hidden = true})
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
          self.ref.progressView.progress = 0.2
          if results["status"] == "success" {
            self.ref.stops = Stop.StopsFromJSON(results["body"])
            self.ref.progressView.progress = 0.3
            self.ref.api.getVehicleActivities()
          } else {
            self.ref.progressView.hidden = true
            let errorTitle = results["data"]["title"] ?? "unknown error"
            let errorMessage = results["data"]["message"] ?? "unknown details"
            let alertController = UIAlertController(title: "Network error", message:
              "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.ref.presentViewController(alertController, animated: true, completion: nil)
          }
          
          // Load initial vehicle data after stops have been read
        })
      }
    }
    
    return APIController(vehDelegate: VehicleDelegate(ref: self), stopsDelegate: StopsDelegate(ref: self))
  }()
  
  // MARK: - lifecycle
  override func viewDidLayoutSubviews() {
    
    // debugging
    var i = 0
    for c in vehicleHeaderViews {
      if let v = c.value {
        println("v\(i) frame: \(v.frame)")
        println("v\(i) bounds: \(v.bounds)")
        println("v\(i) center: \(v.center)")
      }
      ++i
    }

    // update scrollview content width based on the location of the last subview and margins
    if let last = vehicleHeaderViews.last?.value, first = vehicleHeaderViews.first?.value {
      let contentWidth = last.frame.maxX
      println("content width: \(contentWidth), \(last.frame.maxX), \(first.frame.minX)")
      for c in scrollView.constraints() {
        if let c = c as? NSLayoutConstraint where c.firstAttribute == .Trailing {
          c.constant = contentWidth - first.frame.maxX + first.frame.minX
          println("constraint constant: \(c.constant)")
        }
      }
    }

    // calculate the page width for the scrollview
    if vehicleHeaderViews.count > 1 {
      let first = vehicleHeaderViews[0].value!
      let second = vehicleHeaderViews[1].value!
      scrollViewPageWidth = second.center.x - first.center.x
      println("scrollViewPageWidth: \(scrollViewPageWidth)")
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast
    //    scrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
    
    vehicleHeaderViews.append(WeakContainer(vehicleHeaderView))
    let tempArchive = NSKeyedArchiver.archivedDataWithRootObject(vehicleHeaderView)
    for i in 1..<maxVehicleCount {
      let nextVehicleHeaderView = NSKeyedUnarchiver.unarchiveObjectWithData(tempArchive) as! UIView
      vehicleHeaderViews.append(WeakContainer(nextVehicleHeaderView))
      
      scrollView.addSubview(nextVehicleHeaderView)
//      nextVehicleHeaderView.setTranslatesAutoresizingMaskIntoConstraints(false);
      
      let offsetConstraint = NSLayoutConstraint(item: nextVehicleHeaderView, attribute: .Leading, relatedBy: .Equal,
        toItem: vehicleHeaderViews[i - 1].value, attribute: NSLayoutAttribute.Right, multiplier: 1, constant: scrollVIewContentMargin)
      offsetConstraint.active = true
      let topConstraint = NSLayoutConstraint(item: nextVehicleHeaderView, attribute: .Top, relatedBy: .Equal, toItem: nextVehicleHeaderView.superview, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0)
      topConstraint.active = true
      
    }
    println("scrollView bounds: \(scrollView.bounds), frame: \(scrollView.frame), contentsize: \(scrollView.contentSize)")

    NSNotificationCenter.defaultCenter().addObserver(self, selector: "locationUpdated:", name: "newLocationNotif", object: nil)
    
    if let toggle = refreshToggle.customView as? UISwitch {
      autoRefresh = toggle.on
    }
    
    initAutoRefreshTimer()
    println("Intial refresh")
    refreshData()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  // MARK: - actions
  @IBAction func refreshToggled(sender: AnyObject) {
    if let toggle = refreshToggle.customView as? UISwitch {
      autoRefresh = toggle.on
      initAutoRefreshTimer()
    }
  }

  // MARK: - utility functions
  private func initAutoRefreshTimer() {
    autoRefreshTimer?.invalidate()
    if autoRefresh {
      autoRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "timedRefreshRequested:", userInfo: nil, repeats: true)
      //      autoRefreshTimer?.tolerance =
      println("Refresh enabled")
    } else {
      println("Refresh disabled")
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
  
  
  func refreshData() {
    progressView.progress = 0
    progressView.alpha = 0
    progressView.hidden = false
    UIView.transitionWithView(progressView,
      duration: 0.2, options: UIViewAnimationOptions.TransitionCrossDissolve,
      animations: {self.progressView.alpha = 1}, completion: nil)
    println("Refresh requested1")
    api.getStops()
  }
  
  func timedRefreshRequested(timer: NSTimer) {
    refreshData()
  }
  
}

// MARK: - UITableViewDataSource
extension SearchResultsViewController: UITableViewDataSource {
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return closestVehicle?.stops.count ?? 0
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
      return vehicles.count + 1
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
//             ----- -----
// |xxxXXXXxxx|xxxXXXXxxx|xxxXXXXxxx|
// MARK: - UIScrollViewDelegate
extension SearchResultsViewController: UIScrollViewDelegate {
  
  func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
    println("scroll end on page: \(floor((scrollView.contentOffset.x + scrollViewPageWidth / 2) / scrollViewPageWidth))")
  }
  
  // paging for scrollview
  func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    
    var currentOffset = CGFloat(scrollView.contentOffset.x)
    var targetOffset = CGFloat(targetContentOffset.memory.x)
    var newTargetOffset = CGFloat(0)
    
//    if targetOffset > currentOffset {
      newTargetOffset = round((targetOffset) / scrollViewPageWidth) * scrollViewPageWidth
//    } else {
//      newTargetOffset = floor(currentOffset / scrollViewPageWidth) * scrollViewPageWidth
//    }
    
    if newTargetOffset < 0 {
      newTargetOffset = 0
    }
    
    if velocity.x != 0 && newTargetOffset != targetOffset {
      if velocity.x > 0 {
        newTargetOffset = ceil((targetOffset - scrollViewPageWidth / 2) / scrollViewPageWidth ) * scrollViewPageWidth
        targetContentOffset.memory.x = newTargetOffset
      } else {
        newTargetOffset = floor((targetOffset + scrollViewPageWidth / 2) / scrollViewPageWidth ) * scrollViewPageWidth
        targetContentOffset.memory.x = newTargetOffset
      }
    } else {
      scrollView.setContentOffset(CGPointMake(CGFloat(newTargetOffset), 0), animated: true)
    }
    
  }
}