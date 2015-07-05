//
//  LineVehicles.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 4.7.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftyJSON

class LineVehicles {
  var vehicles = [VehicleActivity]()

  var count: Int {
    return vehicles.count
  }
  
  init () {
  }
  
  init (fromJSON result: JSON) {
  
    for (index: String, subJson: JSON) in result {
      vehicles.removeAll(keepCapacity: false)
      
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
        vehicles.append(v)
      }
    }
  }
 
  func getFirstVehicle() -> VehicleActivity? {
    return vehicles.first
  }

  func getClosestVehicle(userLocation: CLLocation) -> VehicleActivity? {
    var sortedMatchingVehicles = sorted(vehicles) {userLocation.distanceFromLocation($0.loc!) < userLocation.distanceFromLocation($1.loc!)}
    return sortedMatchingVehicles.first
  }
}

