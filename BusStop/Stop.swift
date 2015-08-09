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
import RealmSwift


public class Stop : Object, Printable {
  public dynamic var id: String = ""
  public dynamic var name: String = ""
  public dynamic var latitude: CLLocationDegrees = 0.0
  public dynamic var longitude: CLLocationDegrees = 0.0
  public dynamic var location: CLLocation {return CLLocation(latitude: latitude, longitude: longitude)}
  public dynamic var favorite = false
  
  public convenience init(id: String, name: String, location: CLLocation? = nil) {
    self.init()

    self.id = id
    self.name = name
    latitude = location?.coordinate.latitude ?? 0.0
    longitude = location?.coordinate.longitude ?? 0.0
  }

  public func distanceFromUserLocation(userLocation: CLLocation) -> String {
    if latitude != 0 && longitude != 0 {
      let dist = location.distanceFromLocation(userLocation)
      if dist == 0 {
        return NSLocalizedString("Exactly at your location", comment: "")
      } else if dist < 1000 {
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
  
  override public class func primaryKey() -> String? {
    return "id"
  }
  
  override public class func ignoredProperties() -> [String] {
    return ["location"]
  }
  
  override public var description: String {
    return name
  }

}
