//
//  VehicleActivity.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 12.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import SwiftyJSON
import CoreLocation

class VehicleActivity {
  
  let vehRef: String
  var loc: CLLocation?
  var stops = [NSURL]()
  
  static func VehicleActivitiesFromJSON(result: JSON) -> [VehicleActivity]{
    var activities = [VehicleActivity]()
    
    for (index: String, subJson: JSON) in result {
      let monVeh = subJson["monitoredVehicleJourney"]
      if let vehRef = monVeh["vehicleRef"].string where !vehRef.isEmpty{
        var v = VehicleActivity(vehicleRef: vehRef)

        let locJson = monVeh["vehicleLocation"]
        if let lat = locJson["latitude"].string?.fromPOSIXStringtoDouble(), lon = locJson["longitude"].string?.fromPOSIXStringtoDouble() {
          let locTest = CLLocationCoordinate2DMake(lat, lon)
          if CLLocationCoordinate2DIsValid(locTest) {
            v.loc = CLLocation(latitude: lat, longitude: lon)
          }
        }
        let stops = monVeh["onwardCalls"]
        for (index: String, subJson: JSON) in stops {
          if let stopRef = subJson["stopPointRef"].string {
            v.addStopAsString(stopRef)
          }
        }
        activities.append(v)
      }
    }
    return activities
  }
  
  init(vehicleRef vehRef: String) {
    self.vehRef = vehRef
  }
    
  func getNextStop() -> NSURL? {
    if stops.count > 0 {
      return stops[0]
    } else {
      return nil
    }
    
  }

  func addStopAsString(stopRef: String) {
    if let url = NSURL(fileURLWithPath: stopRef) {
      stops.append(url)
    }
  }
}

