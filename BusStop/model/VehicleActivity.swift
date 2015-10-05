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
// MARK: - VechileActivity
//
class VehicleActivity : Equatable {
  
  enum Operator: String {
    case TKL = "tkl"
    case LL = "ll"
    case Paunu = "paunu"
    
    init?(operatorRef ref: String) {
      switch ref.lowercaseString {
      case TKL.rawValue:
        self = .TKL
      case LL.rawValue:
        self = .LL
      case Paunu.rawValue:
        self = .Paunu
      default:
        return nil
      }
    }
    
    func name() -> String {
      switch self {
      case TKL: return "TKL"
      case LL: return "Länsilinja"
      case Paunu: return "Paunu"
      default: return "other"
      }
    }
  }
  
  struct VehicleActivityStop {
    var id: String
    let expectedArrivalTime: NSDate
    let expectedDepartureTime: NSDate
    let order: Int
  }

  // MARK: - properties
  let lineRef: String
  let vehicleRef: String
  var location: CLLocation?
  var stops: [VehicleActivityStop] = []
  let delay: NSTimeInterval
  var description: String {
    return "vehicleRef: \(vehicleRef), loc: \(location?.coordinate.latitude.toString(fractionDigits: 2)):\(location?.coordinate.longitude.toString(fractionDigits: 2))"
  }
  let vehicleOperator: Operator?
  var lastUpdated = NSDate()
 
  // MARK: - initialization
  init?(fromJSON monVeh: JSON) {
    if let vehicleRef = monVeh["vehicleRef"].string, lineRef = monVeh["lineRef"].string, operatorRef = monVeh["operatorRef"].string
      where !vehicleRef.isEmpty && !lineRef.isEmpty {
        self.vehicleRef = vehicleRef
        self.lineRef = lineRef
        self.vehicleOperator = Operator(operatorRef: operatorRef)
        
        let delayString = monVeh["delay"].string
        self.delay = delayString?.fromStringToTimeInterval() ?? 0
        
        setLocationFromJSON(monVeh)
        setStopsFromJSON(monVeh)
        
    } else {
      lastUpdated = NSDate()
      log.error("failed to parse vehicle activity from JSON: \(monVeh)")
      self.vehicleRef = ""
      self.vehicleOperator = nil
      self.lineRef = ""
      self.delay = 0
      return nil
    }
  }
  
  var formattedVehicleRef: String {
    let comps = vehicleRef.componentsSeparatedByString("_")
    if comps.count == 2 {
      if let vehicleOperator = vehicleOperator where comps.count == 2 {
        return "\(vehicleOperator.name()) \(comps[1])"
      } else {
        return "\(comps[0]) \(comps[1])"
      }
    } else {
      return vehicleRef
    }
  }
  
  var nextStop: VehicleActivityStop? {
    if stops.count > 0 {
      return stops[0]
    } else {
      return nil
    }
  }
  
  func stopById(id: String) -> VehicleActivityStop? {
    if let index = stopIndexById(id) {
      return stops[index]
    } else {
    return nil
    }
  }
//
//  func stopIndexByRef(ref: NSURL) -> Int? {
//    for i in 0..<stops.count {
//      if stops[i].ref == ref {
//        return i
//      }
//    }
//    return nil
//  }

  func stopIndexById(id: String) -> Int? {
    for i in 0..<stops.count {
      if stops[i].id == id {
        return i
      }
    }
    return nil
  }

  func setStopsFromJSON(monVeh: JSON) {
    self.stops = []
    
    let stops = monVeh["onwardCalls"]
    for (index, subJSON): (String, JSON) in stops {
      let stopRef = subJSON["stopPointRef"].string
      let ref = stopRef != nil ? NSURL(fileURLWithPath: stopRef!): nil
      
      let arrivalString = subJSON["expectedArrivalTime"].string
      let arrivalTime = arrivalString?.fromISO8601StringToDate()
      
      let departureString = subJSON["expectedDepartureTime"].string
      let departureTime = departureString?.fromISO8601StringToDate()
      
      let order = subJSON["order"].string?.toInt()
      
      if let ref = ref, id = ref.lastPathComponent, arrivalTime = arrivalTime, departureTime = departureTime, order = order {
        let stop = VehicleActivityStop(id: id, expectedArrivalTime: arrivalTime,
          expectedDepartureTime: departureTime, order: order)
        self.stops.append(stop)
      } else {
        log.error("Failed to create vehicle activity stop from JSON\n\(subJSON)")
      }
    }
    lastUpdated = NSDate()
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
    lastUpdated = NSDate()
  }

  func distanceFromUserLocation(userLocation: CLLocation) -> String {
    if let dist = location?.distanceFromLocation(userLocation) {
      if dist < 1000 {
        return NSString.localizedStringWithFormat(NSLocalizedString("%d meter(s) from your location", comment: "distance in meters"), lround(dist), userLocation.horizontalAccuracy.toInt()) as String
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

// Implement comparison for Equatable
func == (lhs: VehicleActivity, rhs: VehicleActivity) -> Bool {
  return lhs.vehicleRef == rhs.vehicleRef
}
