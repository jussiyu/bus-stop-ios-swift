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
import XCGLogger

class VehicleActivity : Equatable {
  
  struct VehicleActivityStop {
    var id: String {return ref.lastPathComponent ?? "<invalid ID>"}
    let ref: NSURL
    let expectedArrivalTime: NSDate
    let expectedDepartureTime: NSDate
    let order: Int
  }

  // MARK: - properties
  let lineRef: String
  let vehRef: String
  var location: CLLocation?
  var stops: [VehicleActivityStop] = []
  let delay: NSTimeInterval
  var description: String {
    return "vehRef: \(vehRef), loc: \(location?.coordinate.latitude.toString(fractionDigits: 2)):\(location?.coordinate.longitude.toString(fractionDigits: 2))"
  }
 
  var formattedVehicleRef: String {
    let comps = vehRef.componentsSeparatedByString("_")
    if comps.count == 2 {
      return "\(comps[0]) \(comps[1])"
    } else {
      return vehRef
    }
  }
  
  var nextStop: VehicleActivityStop? {
    if stops.count > 0 {
      return stops[0]
    } else {
      return nil
    }
  }
  
  func stopByRef(ref: NSURL) -> VehicleActivityStop? {
    if let index = stopIndexByRef(ref) {
      return stops[index]
    } else {
    return nil
    }
  }

  func stopIndexByRef(ref: NSURL) -> Int? {
    for i in 0..<stops.count {
      if stops[i].ref == ref {
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
      
      let delayString = monVeh["delay"].string
      self.delay = delayString?.fromStringToTimeInterval() ?? 0
      
      setLocationFromJSON(monVeh)
      setStopsFromJSON(monVeh)
      
    } else {
      log.error("failed to parse vehicle activity from JSON: \(monVeh)")
      self.vehRef = ""
      self.lineRef = ""
      self.delay = 0
      return nil
    }
  }
  
  func setStopsFromJSON(monVeh: JSON) {
    self.stops = []
    
    let stops = monVeh["onwardCalls"]
    for (index: String, subJSON: JSON) in stops {
      let stopRef = subJSON["stopPointRef"].string
      let url = stopRef != nil ? NSURL(fileURLWithPath: stopRef!): nil
      
      let arrivalString = subJSON["expectedArrivalTime"].string
      let arrivalTime = arrivalString?.fromISO8601StringToDate()
      
      let departureString = subJSON["expectedDepartureTime"].string
      let departureTime = departureString?.fromISO8601StringToDate()
      
      let order = subJSON["order"].string?.toInt()
      
      if let url = url, arrivalTime = arrivalTime, departureTime = departureTime, order = order {
        let stop = VehicleActivityStop(ref: url, expectedArrivalTime: arrivalTime,
          expectedDepartureTime: departureTime, order: order)
        self.stops.append(stop)
      } else {
        log.error("Failed to create vehicle activity stop from JSON\n\(subJSON)")
      }
    }
//    log.info("onwardCalls count: \(stops.count)")
  }

  func setLocationFromJSON(monVeh: JSON) {
    let locJson = monVeh["vehicleLocation"]
    if let lat = locJson["latitude"].string?.fromPOSIXStringToDouble(),
        lon = locJson["longitude"].string?.fromPOSIXStringToDouble() {
      let locTest = CLLocationCoordinate2DMake(lat, lon)
      if CLLocationCoordinate2DIsValid(locTest) {
        self.location = CLLocation(latitude: lat, longitude: lon)
      }
    }
  }

  func distanceFromUserLocation(userLocation: CLLocation) -> String {
    if let dist = location?.distanceFromLocation(userLocation) {
      if dist < 1000 {
        return NSString.localizedStringWithFormat(NSLocalizedString("%d meter(s) from your location", comment: "distance in meters"), lround(dist)) as String
      } else {
        return NSString.localizedStringWithFormat(NSLocalizedString("%d km(s) from your location", comment: "distance in km"), dist/1000) as String
      }
    } else {
      return NSLocalizedString("--", comment: "unknown distance between user and the vehicle")
    }
  }
  
  func distanceFromUserLocation(userLoc: CLLocation) -> CLLocationDistance? {
    return location?.distanceFromLocation(userLoc)
  }
  
  class func vehicleRefFromJSON(monVeh: JSON) -> String? {
    return monVeh["vehicleRef"].string
  }
}

func == (lhs: VehicleActivity, rhs: VehicleActivity) -> Bool {
  return lhs.vehRef == rhs.vehRef
}
