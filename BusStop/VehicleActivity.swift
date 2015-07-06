//
//  VehicleActivity.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 12.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import CoreLocation

class VehicleActivity {
  
  let vehRef: String
  var loc: CLLocation?
  var stops = [NSURL]()
  
  var description: String {
    return "vehRef: \(vehRef), loc: \(loc?.coordinate.latitude.toString(fractionDigits: 2)):\(loc?.coordinate.longitude.toString(fractionDigits: 2))"
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
  
  func getDistanceFromUserLocation(userLoc: CLLocation) -> String {
    if let dist = loc?.distanceFromLocation(userLoc) {
      if dist < 1000 {
        return NSString.localizedStringWithFormat(NSLocalizedString("%d meter(s) from your location", comment: "distance in meters"), lround(dist)) as String
      } else {
        return NSString.localizedStringWithFormat(NSLocalizedString("%d km(s) from your location", comment: "distance in km"), 4) as String
//        return "\((dist/1000).toString(fractionDigits: 1)) km".localizedWithComment("distance in km")
      }
    } else {
      return "--".localizedWithComment("unknown distance between user and the vehicle")
    }
    
  }
  
  func getDistanceFromUserLocation(userLoc: CLLocation) -> CLLocationDistance? {
    return loc?.distanceFromLocation(userLoc)
  }
  
}

