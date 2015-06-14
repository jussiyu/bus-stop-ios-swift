//
//  ViewController.swift
//  jamesonquave
//
//  Created by Jussi Yli-Urpo on 3.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit
import SwiftyJSON

class SearchResultsViewController: UIViewController {
  
  @IBOutlet weak var lineField: UITextField!
  @IBOutlet var vehicleField : UITextField!
  @IBOutlet weak var stopField: UITextField!
  @IBOutlet var vehicleTableView: UITableView!
  @IBOutlet weak var pickerView: UIPickerView!
  
  private var vehicleActivities = [VehicleActivity]()
  private var matchingVehicles = [VehicleActivity]()
  
  private var stops = [String: Stop]()

  
  var imageCache = [String:UIImage]()
  let kCellIdentifier: String = "SearchResultCell"
  
  lazy private var api: APIController = {

    class VehicleDelegate: APIControllerProtocol {
      let ref: SearchResultsViewController
      init(ref: SearchResultsViewController) {
        self.ref = ref
      }
      func didReceiveAPIResults(results: JSON) {
        dispatch_async(dispatch_get_main_queue(), {
          self.ref.vehicleActivities = VehicleActivity.VehicleActivitiesFromJSON(results["body"])
          self.ref.vehicleTableView!.reloadData()
          self.ref.pickerView.selectRow(0, inComponent: 1, animated: true)
          self.ref.pickerView(self.ref.pickerView, didSelectRow: 0, inComponent: 1)
          self.ref.pickerView.reloadAllComponents()
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
          self.ref.stops = Stop.StopsFromJSON(results["body"])
        })
      }
    }
    
    return APIController(vehDelegate: VehicleDelegate(ref: self), stopsDelegate: StopsDelegate(ref: self))
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    lineField.text = "1"
    vehicleField.text = ""
    doLoadVehicleData()
    api.getStops()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func inputFieldChanged(sender: AnyObject) {
    doLoadVehicleData()
  }
  
  @IBAction func viewTapped(sender: AnyObject) {
    vehicleField.resignFirstResponder()
    lineField.resignFirstResponder()
  }
  
  func doLoadVehicleData() {
    var lineId = 1
    if let userLineId = lineField.text.toInt() {
      lineId = userLineId
    }
    
    api.getVehicleActivitiesForLine(lineId)
  }
}

extension SearchResultsViewController: UITableViewDataSource {

  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    var searchString = vehicleField.text.stringByReplacingOccurrencesOfString("*", withString: "")
    matchingVehicles = [VehicleActivity]()
    if searchString.isBlank {
      for veh in vehicleActivities {
        matchingVehicles.append(veh)
      }
    } else {
      for veh in vehicleActivities {
        if veh.vehRef == searchString {
          matchingVehicles.append(veh)
        }
      }
    }
    return matchingVehicles.count
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier, forIndexPath:indexPath) as! UITableViewCell

    if vehicleActivities.count > indexPath.row {
      let veh = matchingVehicles[indexPath.row]
      cell.textLabel?.text = veh.vehRef
      if let nextStopURL = veh.getNextStop() {
        if let nextStopId = nextStopURL.lastPathComponent {
          if let stop = stops[nextStopId] {
            cell.detailTextLabel?.text = stop.name
          } else {
            cell.detailTextLabel?.text = nextStopId
          }
        } else {
          cell.detailTextLabel?.text = "?? no stop id in ref ??"
        }
        if stopField.text != "" && stopField.text == nextStopURL.lastPathComponent {
          cell.backgroundColor = UIColor.yellowColor()
        }
      } else {
        cell.detailTextLabel?.text = "<no stops>"
      }
    } else {
      cell.textLabel?.text = "??????"
    }
    return cell
  }
  
}

// MARK: - UITableViewDelegate
extension SearchResultsViewController: UITableViewDelegate {
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    vehicleField.resignFirstResponder()
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
      return vehicleActivities.count + 1
    default:
      return 0
    }
  }
  
  func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
    return 2
  }
}

// MARK: - UIPickerViewDelegate
extension SearchResultsViewController: UIPickerViewDelegate {
  
  func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    switch component {
    case 0:
      lineField.text = self.pickerView(pickerView, titleForRow: row, forComponent: 0)
      doLoadVehicleData()
    case 1:
      if row == 0 {
        vehicleField.text = ""
      } else {
        vehicleField.text = self.pickerView(pickerView, titleForRow: row, forComponent: 1)
      }
      vehicleTableView.reloadData()
    default:
      println("Invalid component \(component) selected")
    }
  }
  
  
  func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
    switch component {
    case 0:
      return "\(row + 1)"
    case 1:
      if row == 0 {
        return "All busses"
      } else if vehicleActivities.count + 1 > row {
        return vehicleActivities[row - 1].vehRef
      } else {
        return "?? unknown row \(row) ??"
      }
    default:
      return "?? unknown component \(row) ??"
    }
  }
}

//MARK: - APIControllerProtocol
extension SearchResultsViewController: APIControllerProtocol {
  func didReceiveAPIResults(results: JSON) {
    dispatch_async(dispatch_get_main_queue(), {
      self.vehicleActivities = VehicleActivity.VehicleActivitiesFromJSON(results["body"])
      self.vehicleTableView!.reloadData()
      self.pickerView.selectRow(0, inComponent: 1, animated: true)
      self.pickerView(self.pickerView, didSelectRow: 0, inComponent: 1)
      self.pickerView.reloadAllComponents()
    })
  }
}
