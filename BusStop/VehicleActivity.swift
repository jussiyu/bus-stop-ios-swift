//
//  VehicleActivity.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 12.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftyJSON

class VehicleActivity {
 
  let lineRef: String
  let vehRef: String
  var loc: CLLocation?
  var stops: [NSURL] = [NSURL]()
  var description: String {
    return "vehRef: \(vehRef), loc: \(loc?.coordinate.latitude.toString(fractionDigits: 2)):\(loc?.coordinate.longitude.toString(fractionDigits: 2))"
  }
 
  init?(fromJSON monVeh: JSON) {
    if let vehRef = monVeh["vehicleRef"].string, lineRef = monVeh["lineRef"].string where !vehRef.isEmpty && !lineRef.isEmpty {
      self.vehRef = vehRef
      self.lineRef = lineRef
      
      let locJson = monVeh["vehicleLocation"]
      if let lat = locJson["latitude"].string?.fromPOSIXStringtoDouble(), lon = locJson["longitude"].string?.fromPOSIXStringtoDouble() {
        let locTest = CLLocationCoordinate2DMake(lat, lon)
        if CLLocationCoordinate2DIsValid(locTest) {
          loc = CLLocation(latitude: lat, longitude: lon)
        }
      }
      let stops = monVeh["onwardCalls"]
      for (index: String, subJson: JSON) in stops {
        if let stopRef = subJson["stopPointRef"].string {
          if let url = NSURL(fileURLWithPath: stopRef) {
            self.stops.append(url)
          }
        }
      }
    } else {
      self.vehRef = ""
      self.lineRef = ""
      return nil
    }
  }
  
  
  func addStopAsString(stopRef: String) {
    if let url = NSURL(fileURLWithPath: stopRef) {
      stops.append(url)
    }
  }

  func getFormattedVehicleRef() -> String {
    let comps = vehRef.componentsSeparatedByString("_")
    if comps.count == 2 {
      return "\(comps[0]) \(comps[1])"
    } else {
      return vehRef
    }
  }
  
  func getNextStop() -> NSURL? {
    if stops.count > 0 {
      return stops[0]
    } else {
      return nil
    }
  
  }
  
  
  func getDistanceFromUserLocation(userLoc: CLLocation) -> String {
    if let dist = loc?.distanceFromLocation(userLoc) {
      if dist < 1000 {
        return NSString.localizedStringWithFormat(NSLocalizedString("%d meter(s) from your location", comment: "distance in meters"), lround(dist)) as String
      } else {
        return NSString.localizedStringWithFormat(NSLocalizedString("%d km(s) from your location", comment: "distance in km"), dist/1000) as String
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

