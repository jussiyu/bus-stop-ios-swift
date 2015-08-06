////
////  Stops.swift
////  BusStop
////
////  Created by Jussi Yli-Urpo on 5.8.15.
////  Copyright (c) 2015 Solipaste. All rights reserved.
////
//
//import Foundation
//import XCGLogger
//import SwiftyJSON
//import CoreLocation
//import RealmSwift
//
//class Stops: Object {
//  let stops = List<Stop>()
//  
//  subscript(index: Int) -> Stop {
//    for stop in stops {
//      if stop.id.toInt() == index {
//        return stop
//      }
//    }
//  }
//  
//  required init() {
//    super.init()
//  }
//  
//  init (fromJSON result: JSON) {
//    for (index: String, subJson: JSON) in result {
//      if let id = subJson["shortName"].string, name = subJson["name"].string where !id.isEmpty {
//        
//        let locString = subJson["location"].string
//        let coordinates = locString?.componentsSeparatedByString(",")
//        var location: CLLocation? = nil
//        if let coordinates = coordinates where coordinates.count == 2 {
//          if let lat = coordinates[0].fromPOSIXStringToDouble(),
//            lon = coordinates[1].fromPOSIXStringToDouble() {
//              let locTest = CLLocationCoordinate2DMake(lat, lon)
//              if CLLocationCoordinate2DIsValid(locTest) {
//                location = CLLocation(latitude: lat, longitude: lon)
//              }
//          }
//        }
//        
//        var s = Stop(id: id, name: name, location: location)
//        stops.append(s)
//      }
//    }
//    log.debug("Parsed \(count) stops")
//  }
//
//  required init() {
//      fatalError("init() has not been implemented")
//  }
//
//}
