//
//  StopDBManager.swift
//  BusStop
//
//  Created by Jussi Yli-Urpo on 5.8.15.
//  Copyright (c) 2015 Solipaste. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftyJSON
import XCGLogger
import RealmSwift
import Async

class StopDBManager {
  
  // Multiton instance per thread
  static var instances: [mach_port_t: StopDBManager] = [:]
  
  /// A thread specific instance of StipDBManager
  static var sharedInstance: StopDBManager {
    var currentThread = pthread_mach_thread_np(pthread_self())
    synchronize(self) {
      if self.instances[currentThread] == nil {
        self.instances[currentThread] = StopDBManager()
        log.debug("Created StopDBManager instance for \(currentThread)")
      }
    }
    return self.instances[currentThread]!
  }
  private init() {}

  let realm = Realm()


  var stopCount: Int {
    return realm.objects(Stop).count
  }
  
  func initFromJSON(result: JSON) {
    var count = 0

    realm.write {
      self.realm.deleteAll()
      
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
          
          self.realm.add(s)
          ++count
        }
      }
    }
    
    log.debug("Parsed \(count) stops")
  }
  
  func stopWithId(id: String) -> Stop? {
    return realm.objectForPrimaryKey(Stop.self, key: id)
  }
  
  func setFavoriteForStop(stop: Stop, favorite: Bool) {
    realm.write {
      stop.favorite = favorite
    }
  }
  
}

