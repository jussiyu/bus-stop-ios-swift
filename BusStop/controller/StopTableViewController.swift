//
//  StopTableTableViewController.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 14.8.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import UIKit
import CoreLocation

protocol MainDelegate {
  func resetVehicleScrollView()
  func getSelectedVehicle() ->VehicleActivity?
  func expandStopContainer()
  func expandStopContainerByOffset(offset: CGFloat)
  func unexpandStopContainer()
  func stopSelected()
  func stopUnselected()
  func getUserLocation() -> CLLocation?
}

extension StopTableViewController: StopDelegate {
  func unselectStop() {
    doUnselectStop()
  }
}

class StopTableViewController: UITableViewController {
  
  var tableViewHeader: UILabel?
  let defaultCellIdentifier: String = "StopCell"
  let selectedCellIdentifier: String = "SelectedStopCell"

  var mainDelegate: MainDelegate?
  
  /// a thread specific instance - do not reuse across threads
  var stopDBManager: StopDBManager { return StopDBManager.sharedInstance }
  
  var selectedStopId: String? {
    didSet {
      log.debug("SelectedStopId set to \(self.selectedStop)")
      // TODO userNotifiedForSelectedStop = false
    }
  }
  
  // Not retained as a strong reference in order to avoid duplicates after an vehicles refresh
  var selectedStop: Stop? {
    if let selectedStopId = selectedStopId {
      return stopDBManager.stopWithId(selectedStopId)
    } else {
      return nil
    }
  }
  
  var selectedVehicle: VehicleActivity? {
    return mainDelegate?.getSelectedVehicle()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - Table view data source
  
  //    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
  //        // #warning Potentially incomplete method implementation.
  //        // Return the number of sections.
  //        return 0
  //    }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let mapController = segue.destinationViewController as? MapViewController,
      cell = sender as? UITableViewCell where segue.identifier == "showStopOnMap" {
        if let stopRow = tableView.indexPathForCell(cell)?.row {
          mapController.selectedStop = stopForRow(stopRow)
        }
        mapController.userLocation = mainDelegate?.getUserLocation()
        mapController.selectedVehicle = selectedVehicle
    }
  }

  
  //data source
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
    // if a stop is selected then only it will be shown
    if let selectedStop = selectedStop {
      return 1
    } else {
      return selectedVehicle?.stops.count ?? 0
    }
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    
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
      let stopCountLabelFont = UIFont(descriptor: UIFontDescriptor.preferredDescriptorWithStyle(UIFontTextStyleHeadline, oversizedBy: 20), size: 0)
      cell.stopCountLabel.font = stopCountLabelFont
      
      if let selectedStopIndex = selectedVehicle.stopIndexById(selectedStop.id) {
        cell.stopCountLabel.text = String(selectedStopIndex)
        
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
        //TODO: cell.distanceHintLabel.text = autoUnexpandTaskQueueProgress ?? ""
        cell.stopCountLabel.text = ""
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
      
      // Favourite button
      cell.favoriteButton.selected = selectedStop.favorite
      cell.favoriteButton.removeTarget(nil, action: nil, forControlEvents: .TouchUpInside)
      cell.favoriteButton.addTarget(self, action: "selectedStopFavoriteButtonPressed:", forControlEvents: .TouchUpInside)
      
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
    
    doUnselectStop()
  }
  
  func selectedStopFavoriteButtonPressed(sender: AnyObject) {
    log.verbose("")
    
    if let button = sender as? UIButton {
      button.selected = !button.selected
      if let selectedStop = selectedStop {
        stopDBManager.setFavoriteForStop(selectedStop, favorite: button.selected)
      }
    }
  }
  
  //// Delegate
  override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    tableViewHeader = UILabel()
    //TODO: if closestVehicles.count > 0 {
      if selectedStopId == nil {
        tableViewHeader!.text = NSLocalizedString("Choose your stop", comment: "")
      } else {
        tableViewHeader!.text = NSLocalizedString("Now tracking your stop", comment: "")
      }
//    } else {
//      stopTableViewHeader!.text = ""
//    }
    tableViewHeader!.textAlignment = .Center
    tableViewHeader!.backgroundColor = UIColor.whiteColor()
    return tableViewHeader
  }
  
  override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 22
  }
  
  override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
    if selectedStopId == nil {
      return tableView.rowHeight
    } else {
      return tableView.bounds.height - (tableViewHeader?.bounds.height ?? 0)
    }
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    log.verbose("vehicleScrollView:didSelectRowAtIndexPath: \(indexPath.row)")
    
    if selectedStopId == nil {
      doSelectStopAtIndexPath(indexPath)
    } else {
      // There is a dedicated close button on the view so do nothing here
    }
  }
  
//  func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
//    
//  }
  
  override func scrollViewDidScroll(scrollView: UIScrollView) {
    super.scrollViewDidScroll(scrollView)
    // Dim the vehicle scroller and move it up
    // Also slide adjacent headers to the side
    
    // Do nothing if all rows fit so that bouncing does nothing
    if scrollView.bounds.height < scrollView.contentSize.height {
      
      // scroll stop table view up and minimize vehicle scroller
      // Use the positive value of the table scroll offset to animate other views
      let offset = max(scrollView.contentOffset.y, 0)
      //    log.debug("vehicleScrollView vertical offset: \(offset)")
      mainDelegate?.expandStopContainerByOffset(offset)
      
    } else {
      
      // ensure that everything is reset to normal
      mainDelegate?.resetVehicleScrollView()
    }
  }
  
  func stopForRow(row: Int) -> Stop? {
    if let selectedVehicle = selectedVehicle where selectedVehicle.stops.count > row {
      let vehicleActivityStop = selectedVehicle.stops[row]
      if let stop = stopDBManager.stopWithId(vehicleActivityStop.id) {
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
  
  private func doSelectStopAtIndexPath(indexPath: NSIndexPath) {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)
    
    tableView.scrollEnabled = false
    
    // no row was selected when the row was tapped => remove other rows
    
    // store the stop for the selected row
    selectedStopId = stopForRow(indexPath.row)?.id
    if selectedStopId == nil {
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
    
    // perform the correct update operation
    tableView.beginUpdates()
    if let header = tableViewHeader {
      header.text = NSLocalizedString("Now tracking your stop", comment: "")
    }
    tableView.deleteRowsAtIndexPaths(indexPathsOnAbove, withRowAnimation: .Fade)
    tableView.deleteRowsAtIndexPaths(indexPathsOnBelow, withRowAnimation: .Fade)
    
    tableView.endUpdates()
    
    // Maximize the table view
    mainDelegate?.expandStopContainer()
    tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Fade)
    
    mainDelegate?.stopSelected()
  }
  
  private func doUnselectStop() {
    appDelegate.stopUpdatingLocation(handleReceivedLocations: false)
    
    tableView.scrollEnabled = true
    
    tableView.deselectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), animated: true)
    // the tapped (and only) row was already selected => add other rows back
    
    // calculate the final row for the selected stop (or nil)
    var newRowForSelectedStop = selectedStopId != nil ? rowForStop(selectedStop!) : nil
    
    // reset the selection
    selectedStopId = nil
    
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
    tableView.beginUpdates()
    
    if let header = tableViewHeader {
      header.text = NSLocalizedString("Choose your stop", comment: "")
    }
    
    // decide what to do with the current row (on row #0)
    let currentSelectedRowIndexPath = NSIndexPath(forRow: 0, inSection: 0)
    if let newRowForSelectedStop = newRowForSelectedStop {
      // the selected row will exist on the same row (#0) in the restored list so update it
      log.debug("new row for the selected stop is \(newRowForSelectedStop)")
      if newRowForSelectedStop == 0 {
        tableView.reloadRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .Fade)
      } else {
        // the selected row will exist on a new row in the restored list so move it
        //        tableView.moveRowAtIndexPath(currentSelectedRowIndexPath, toIndexPath: NSIndexPath(forRow: newRowForSelectedStop, inSection: 0))
        tableView.reloadRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .None)
      }
      
    } else { // newRowForSelectedStop == nil
      
      log.debug("the selected stop not visible anymore")
      // row does not exist anymore so delete it
      tableView.deleteRowsAtIndexPaths([currentSelectedRowIndexPath], withRowAnimation: .Fade)
    }
    
    // safe to forget now which row was selected
    tableView.insertRowsAtIndexPaths(indexPathsOnAbove, withRowAnimation: UITableViewRowAnimation.Top)
    tableView.insertRowsAtIndexPaths(indexPathsOnBelow, withRowAnimation: UITableViewRowAnimation.Bottom)
    
    tableView.endUpdates()
    
    // Reset the size of the table view
    if let newRowForSelectedStop = newRowForSelectedStop {
      tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: newRowForSelectedStop, inSection: 0), atScrollPosition: .None, animated: true)
    }

    mainDelegate?.stopUnselected()
  }

  
  /*
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
  let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as! UITableViewCell
  
  // Configure the cell...
  
  return cell
  }
  */
  
  /*
  // Override to support conditional editing of the table view.
  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
  // Return NO if you do not want the specified item to be editable.
  return true
  }
  */
  
  /*
  // Override to support editing the table view.
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
  if editingStyle == .Delete {
  // Delete the row from the data source
  tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
  } else if editingStyle == .Insert {
  // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
  }
  }
  */
  
  /*
  // Override to support rearranging the table view.
  override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
  
  }
  */
  
  /*
  // Override to support conditional rearranging of the table view.
  override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
  // Return NO if you do not want the item to be re-orderable.
  return true
  }
  */
  
  /*
  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
  // Get the new view controller using [segue destinationViewController].
  // Pass the selected object to the new view controller.
  }
  */
  
}
