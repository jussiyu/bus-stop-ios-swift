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

class SearchResultsViewController: UIViewController {
  
  @IBOutlet weak var lineLabel: UILabel!
  @IBOutlet weak var vehicleLabel: UILabel!
  @IBOutlet weak var vehicleDistanceLabel: UILabel!
  @IBOutlet var vehicleTableView: UITableView!
  @IBOutlet weak var refreshToggle: UIBarButtonItem!
  
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
            if let closestVehicle = self.ref.closestVehicle, userLoc = self.ref.userLoc {
              self.ref.vehicleLabel.text = closestVehicle.vehRef
              self.ref.vehicleDistanceLabel.text = closestVehicle.getDistanceFromUserLocation(userLoc)
            } else {
              self.ref.vehicleLabel.text = "no busses near you".localizedWithComment("show as vehicle label when no busses near or no user location known")
              self.ref.vehicleDistanceLabel.text = ""
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

  func initAutoRefreshTimer() {
    autoRefreshTimer?.invalidate()
    if autoRefresh {
      autoRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "timedRefreshRequested:", userInfo: nil, repeats: true)
      //      autoRefreshTimer?.tolerance =
      autoRefreshTimer?.fire()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "locationUpdated:", name: "newLocationNotif", object: nil)
    
    if let toggle = refreshToggle.customView as? UISwitch {
      autoRefresh = toggle.on
    }
    
    lineLabel.text = "1"
    vehicleLabel.text = ""
    
    initAutoRefreshTimer()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func inputFieldChanged(sender: AnyObject) {
    doLoadVehicleData()
  }
  
  func doLoadVehicleData() {
    var lineId = 1
    if let userLineId = lineLabel.text?.toInt() {
      lineId = userLineId
    }
    
    api.getVehicleActivitiesForLine(lineId)
  }
  
  func timedRefreshRequested(timer: NSTimer) {
    println("Refresh requested1")
    api.getStops()
  }
  
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
}

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
