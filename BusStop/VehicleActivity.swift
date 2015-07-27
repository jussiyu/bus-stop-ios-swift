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

  // MARK: - properties
  let lineRef: String
  let vehRef: String
  var loc: CLLocation?
  var stops = [NSURL]()
  var description: String {
    return "vehRef: \(vehRef), loc: \(loc?.coordinate.latitude.toString(fractionDigits: 2)):\(loc?.coordinate.longitude.toString(fractionDigits: 2))"
  }
 
  var formattedVehicleRef: String {
    let comps = vehRef.componentsSeparatedByString("_")
    if comps.count == 2 {
      return "\(comps[0]) \(comps[1])"
    } else {
      return vehRef
    }
  }
  
  var nextStop: NSURL? {
    if stops.count > 0 {
      return stops[0]
    } else {
      return nil
    }
  }
  
  func stopIndexByRef(ref: NSURL) -> Int? {
    for i in 0..<stops.count {
      if stops[i] == ref {
        return i
      }
    }
    return nil
  }

  // MARK: - initialization
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
      
      setStopsFromJSON(monVeh)
      
    } else {
      log.error("failed to parse vehicle activity from JSON: \(monVeh)")
      self.vehRef = ""
      self.lineRef = ""
      return nil
    }
  }
  
  func setStopsFromJSON(monVeh: JSON) {
    self.stops = [NSURL]()
    
    let stops = monVeh["onwardCalls"]
    for (index: String, subJson: JSON) in stops {
      if let stopRef = subJson["stopPointRef"].string {
        if let url = NSURL(fileURLWithPath: stopRef) {
          self.stops.append(url)
        }
      }
    }
//    log.info("onwardCalls count: \(stops.count)")
  }

  func distanceFromUserLocation(userLoc: CLLocation) -> String {
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
  
  func distanceFromUserLocation(userLoc: CLLocation) -> CLLocationDistance? {
    return loc?.distanceFromLocation(userLoc)
  }
  
  class func vehicleRefFromJSON(monVeh: JSON) -> String? {
    return monVeh["vehicleRef"].string
  }
}

