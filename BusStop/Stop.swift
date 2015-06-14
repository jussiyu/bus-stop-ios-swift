//
//  Stop.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 12.6.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import SwiftyJSON


class Stop {
  let id: String
  let ref: NSURL?
  let name: String
  
  init(id: String, name: String, ref: String = "") {
    self.id = id
    self.ref = NSURL(fileURLWithPath: ref)
    self.name = name
  }
  
  static func StopsFromJSON(result: JSON) -> [String: Stop]{
    var stops = [String: Stop]()
    
    for (index: String, subJson: JSON) in result {
//      let mun = subJson["municipality"]
      if let id = subJson["shortName"].string,
          stopRef = subJson["url"].string, name = subJson["name"].string where !stopRef.isEmpty {
        var s = Stop(id: id, name: name, ref: stopRef)
        stops[id] = s
      }
    }
    return stops
  }

}
