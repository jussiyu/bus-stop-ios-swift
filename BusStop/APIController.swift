//
//  APIController.swift
//
//  Created by Jussi Yli-Urpo on 4.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import SwiftyJSON

protocol APIControllerProtocol {
  func didReceiveAPIResults(results: JSON)
}

class APIController {
  let delegate: APIControllerProtocol
  
  init(delegate: APIControllerProtocol) {
    self.delegate = delegate
  }
  
  func getVehicleActivitiesForLine(lineId: Int, vehicleId: String) {
//    Uri.Builder uriB = Uri.parse("http://data.itsfactory.fi/journeys/api/1/vehicle-activity")
//      .buildUpon();
//    if (lineId > 0) {
//      uriB.appendQueryParameter("lineRef", lineId.toString());
//    }
//    if (vehId.length() > 0 && !vehId.equals("*")) {
//      uriB.appendQueryParameter("vehicleRef", vehId);
//    }
    var urlPath = "http://data.itsfactory.fi/journeys/api/1/vehicle-activity?lineRef=\(lineId)"

    if(!vehicleId.isBlank) {
      if let escapedVehicleRef = vehicleId.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
        urlPath += "&vehicleRef=\(escapedVehicleRef)"
      }
    }
    
    let url = NSURL(string: urlPath)
    let session = NSURLSession.sharedSession()
    let task = session.dataTaskWithURL(url!, completionHandler: {data, response, urlError -> Void in
      if(urlError != nil) {
        // If there is an error in the web request, print it to the console
        println("Task completed unsuccessfully")
        println(urlError.localizedDescription)
        return
      } else {
        println("Task completed successfully")
      }
      let json = JSON(data: data)
      self.delegate.didReceiveAPIResults(json)
    })
    
    // The task is just an object with all these properties set
    // In order to actually make the web request, we need to "resume"
    task.resume()
  }
}

extension String {
  
  var isBlank: Bool {
    get {
      let trimmed = stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
      return trimmed.isEmpty
    }
  }
  
}
