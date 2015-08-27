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
// MARK: - StopDBManager
//
class StopDBManager {
  
  // Multiton instance per thread
  private static var instances: [mach_port_t: StopDBManager] = [:]
  
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
  private init() {
    log.info("Using Realm database in \(self.realm.path)")
  }

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

