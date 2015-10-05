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
import RealmSwift

//
// MARK: - Stop
//
public class Stop : Object, CustomStringConvertible {
  public dynamic var id: String = ""
  public dynamic var name: String = ""
  public dynamic var latitude: CLLocationDegrees = 0.0
  public dynamic var longitude: CLLocationDegrees = 0.0
  public dynamic var location: CLLocation {
    get {
      return CLLocation(latitude: latitude, longitude: longitude)
    }
    set {
      latitude = newValue.coordinate.latitude
      longitude = newValue.coordinate.longitude
    }
  }
  public dynamic var favorite = false
  
  public convenience init(id: String, name: String, location: CLLocation? = nil) {
    self.init()

    self.id = id
    self.name = name
    latitude = location?.coordinate.latitude ?? 0.0
    longitude = location?.coordinate.longitude ?? 0.0
  }

  public func distanceFromUserLocation(userLocation: CLLocation) -> String {
    if latitude != 0 && longitude != 0 &&
        userLocation.coordinate.latitude != 0 && userLocation.coordinate.longitude != 0{
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
  
  // MARK: - Realm Object class overrides
  override public class func primaryKey() -> String? {
    return "id"
  }
  
  override public class func ignoredProperties() -> [String] {
    return ["location"]
  }

  
  // MARK: - Printable implementation
  override public var description: String {
    return name
  }

}
