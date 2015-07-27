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
  
  init () {
  }
  
  init (fromJSON result: JSON) {

    var vehicleCount = 0
    for (index: String, subJson: JSON) in result {
      let monVeh = subJson["monitoredVehicleJourney"]
      if let v = VehicleActivity(fromJSON: monVeh) {
        vehicles[v.vehRef] = v
        ++vehicleCount
        if vehicleCount >= maxVehiclesToRead {
          break
        }
      }
    }
        log.debug("Vehicles read: \(self.vehicles.count)")
  }
 
  // TODO does not make sense
  func getFirstVehicle() -> VehicleActivity? {
    return vehicles.values.first
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
  
  func setStopsFromJSON(result: JSON) {
    var vehicleCount = 0
    for (index: String, subJson: JSON) in result {
      let monVeh = subJson["monitoredVehicleJourney"]
      if let vehRef = VehicleActivity.vehicleRefFromJSON(monVeh),
        v = vehicles[vehRef] {
          v.setStopsFromJSON(monVeh)
      }
      ++vehicleCount
    }
    log.debug("Stops for vehicles read: \(vehicleCount)")
  }
}

private func isLeftVehicleActivityCloserToUserLocation(userLocation: CLLocation, #left: VehicleActivity, #right: VehicleActivity) -> Bool {
  return left.location != nil && right.location != nil ? (userLocation.distanceFromLocation(left.location!) < userLocation.distanceFromLocation(right.location!)) : false
}
