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
import XCGLogger

class Vehicles {
  var vehicles = [String:VehicleActivity]()
  let maxVehiclesToRead = 500
  
  var count: Int {
    return vehicles.count
  }
  
  var lastUpdated = NSDate()
  
  init () {
  }
  
  init (fromJSON result: JSON) {

    var vehicleCount = 0
    for (index: String, subJson: JSON) in result {
      let monVeh = subJson["monitoredVehicleJourney"]
      if let v = VehicleActivity(fromJSON: monVeh) {
        vehicles[v.vehicleRef] = v
        ++vehicleCount
        if vehicleCount >= maxVehiclesToRead {
          break
        }
      }
    }
    lastUpdated = NSDate()
    log.debug("Vehicles read: \(self.vehicles.count)")
  }
 
  func getClosestVehicle(userLocation: CLLocation) -> VehicleActivity? {
    let sortedMatchingVehicles = sorted(vehicles.values) {isLeftVehicleActivityCloserToUserLocation(userLocation, left: $0, right: $1)}
    let closest = sortedMatchingVehicles.reduce("") { "\($0), \($1.description), "}
//    log.debug("Closest matching vehicles: \(self.closest)")
    return sortedMatchingVehicles.first
  }

  func getClosestVehicles(userLocation: CLLocation, maxCount: Int = 10) -> [VehicleActivity] {
    var sortedVehicles = sorted(vehicles.values) {isLeftVehicleActivityCloserToUserLocation(userLocation, left: $0, right: $1)}
    sortedVehicles.removeRange(min(maxCount,sortedVehicles.count)..<sortedVehicles.endIndex)
    return sortedVehicles
  }

  func setLocationsFromJSON(result: JSON) {
    var vehicleCount = 0
    for (index: String, subJson: JSON) in result {
      let monVeh = subJson["monitoredVehicleJourney"]
      if let vehicleRef = VehicleActivity.vehicleRefFromJSON(monVeh),
        v = vehicles[vehicleRef] {
          v.setLocationFromJSON(monVeh)
      }
      ++vehicleCount
    }
    lastUpdated = NSDate()
    log.debug("Location for vehicles read: \(vehicleCount)")
  }
  
  func setStopsFromJSON(result: JSON) {
    var vehicleCount = 0
    for (index: String, subJson: JSON) in result {
      let monVeh = subJson["monitoredVehicleJourney"]
      if let vehicleRef = VehicleActivity.vehicleRefFromJSON(monVeh),
        v = vehicles[vehicleRef] {
          v.setStopsFromJSON(monVeh)
          log.debug("\(v.stops.count) stops set for \(vehicleRef). 1st is \(v.stops.first?.id)")
      }
      ++vehicleCount
    }
    lastUpdated = NSDate()
  }
}

private func isLeftVehicleActivityCloserToUserLocation(userLocation: CLLocation, #left: VehicleActivity, #right: VehicleActivity) -> Bool {
  return left.location != nil && right.location != nil ? (userLocation.distanceFromLocation(left.location!) < userLocation.distanceFromLocation(right.location!)) : false
}
