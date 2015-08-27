// Copyright (c) 2015 Solipaste Oy
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation
import CoreLocation
import SwiftyJSON
import XCGLogger

//
// MARK: - Vechiles
//
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

/// compare two locations to the userLocation
private func isLeftVehicleActivityCloserToUserLocation(userLocation: CLLocation, #left: VehicleActivity, #right: VehicleActivity) -> Bool {
  return left.location != nil && right.location != nil ? (userLocation.distanceFromLocation(left.location!) < userLocation.distanceFromLocation(right.location!)) : false
}
