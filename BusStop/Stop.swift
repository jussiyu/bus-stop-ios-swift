//
//  Stop.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 12.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftyJSON
import XCGLogger


struct Stop : Printable {
  let id: String
  let name: String
  let location: CLLocation?
  
  init(id: String, name: String, ref: String = "", location: CLLocation?) {
    self.id = id
    self.name = name
    self.location = location
  }
  
    static func StopsFromJSON(result: JSON) -> [String: Stop]{
    var stops = [String: Stop]()
    
    for (index: String, subJson: JSON) in result {
      if let id = subJson["shortName"].string, name = subJson["name"].string where !id.isEmpty {

        let locString = subJson["location"].string
        let coordinates = locString?.componentsSeparatedByString(",")
        var location: CLLocation? = nil
        if let coordinates = coordinates where coordinates.count == 2 {
          if let lat = coordinates[0].fromPOSIXStringToDouble(),
            lon = coordinates[1].fromPOSIXStringToDouble() {
              let locTest = CLLocationCoordinate2DMake(lat, lon)
              if CLLocationCoordinate2DIsValid(locTest) {
                location = CLLocation(latitude: lat, longitude: lon)
              }
          }
        }
        
        var s = Stop(id: id, name: name, location: location)
        stops[id] = s
      }
    }
    log.debug("Parsed \(stops.count) stops")
    return stops
  }

  func distanceFromUserLocation(userLocation: CLLocation) -> String {
    if let dist = location?.distanceFromLocation(userLocation) {
      if dist < 1000 {
        return NSString.localizedStringWithFormat(
          NSLocalizedString("%d meter(s) from your location", comment: "distance in meters"), lround(dist)) as String
      } else {
        return NSString.localizedStringWithFormat(
          NSLocalizedString("%d km(s) from your location", comment: "distance in km"), dist/1000) as String
      }
    } else {
      return NSLocalizedString("--", comment: "unknown distance between user and the vehicle")
    }
    
  }
  
  var description: String {
    return name
  }

}
