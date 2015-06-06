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
  @IBOutlet var appsTableView : UITableView!
  
  private var vehicleData : JSON?
  var imageCache = [String:UIImage]()
  let kCellIdentifier: String = "SearchResultCell"
  
  lazy private var api: APIController = {
    return APIController(delegate: self)
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    lineField.text = "1"
    vehicleField.text = "Paunu*"
    doLoadData()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func lineFieldChanged(sender: AnyObject) {
    doLoadData()
  }
  
  @IBAction func vehicleFieldChanged(sender: AnyObject) {
    doLoadData()
  }
  
  @IBAction func viewTapped(sender: AnyObject) {
    vehicleField.resignFirstResponder()
    lineField.resignFirstResponder()
  }
  
  func doLoadData() {
    var lineId = 1
    if let userLineId = lineField.text.toInt() {
      lineId = userLineId
    }
    api.getVehicleActivitiesForLine(lineId, vehicleId: vehicleField.text)
  }
}

extension SearchResultsViewController: UITableViewDataSource {

  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if let count = vehicleData?.count {
      return count
    } else {
      return 0
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier, forIndexPath:indexPath) as! UITableViewCell
    
    let rowData = self.vehicleData?[indexPath.row]["monitoredVehicleJourney"]
      // Grab the artworkUrl60 key to get an image URL for the app's thumbnail
    if let vehRef = rowData?["vehicleRef"].string,
      firstStopRef = rowData?["onwardCalls"][0]["stopPointRef"].string {
      cell.textLabel?.text = vehRef
        // Update the textLabel text to use the trackName from the API
      cell.detailTextLabel?.text = firstStopRef
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

//MARK: - APIControllerProtocol
extension SearchResultsViewController: APIControllerProtocol {
  func didReceiveAPIResults(results: JSON) {
    dispatch_async(dispatch_get_main_queue(), {
      self.vehicleData = results["body"]
      self.appsTableView!.reloadData()
    })
  }
}



