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
}

