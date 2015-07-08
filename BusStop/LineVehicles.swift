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
      let monVeh = subJson["monitoredVehicleJourney"]
      if var v = VehicleActivity(fromJSON: monVeh) {
        vehicles.append(v)
      }
    }
    //    println("Vehicles read: \(vehicles.count)")
  }
 
  func getFirstVehicle() -> VehicleActivity? {
    return vehicles.first
  }

  func getClosestVehicle(userLocation: CLLocation) -> VehicleActivity? {
    let sortedMatchingVehicles = sorted(vehicles) {$0.loc != nil && $1 != nil ? (userLocation.distanceFromLocation($0.loc!) < userLocation.distanceFromLocation($1.loc!)) : false}
    let closest = sortedMatchingVehicles.reduce("") { "\($0), \($1.description), "}
//    println("Closest matching vehicles: \(closest)")
    return sortedMatchingVehicles.first
  }

  func getClosestVehicles(userLocation: CLLocation) -> [VehicleActivity] {
    return sorted(vehicles) {userLocation.distanceFromLocation($0.loc!) < userLocation.distanceFromLocation($1.loc!)}
  }
}

