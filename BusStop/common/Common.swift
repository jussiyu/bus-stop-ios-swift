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


// MARK: - CLLocation
extension CLLocation {
  /// compare horizontal location accuracy to a another location
  func moreAccurateThanLocation(other: CLLocation) -> Bool {
    return self.horizontalAccuracy < other.horizontalAccuracy
  }
  
  /// Is this location in same horizontal position than the anothe one
  func commonHorizontalLocationWith (other: CLLocation) -> Bool {
    return self.coordinate.longitude == other.coordinate.longitude && self.coordinate.latitude == other.coordinate.latitude
  }
  
  // Based on https://stackoverflow.com/questions/7278094/moving-a-cllocation-by-x-meters
  /// Return coordinate from 'distance' meters to 'direction' direction from this location
  func coordinateWithDirection(direction: CLLocationDirection, distance distanceMeters: CLLocationDistance) -> CLLocationCoordinate2D {
    let distRadians = distanceMeters / (6372797.6)
    
    let rDirection = direction * M_PI / 180.0
    
    let lat1 = self.coordinate.latitude * M_PI / 180
    let lon1 = self.coordinate.longitude * M_PI / 180
    
    let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(rDirection))
    let lon2 = lon1 + atan2(sin(rDirection) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
    
    return CLLocationCoordinate2D(latitude: lat2 * 180 / M_PI, longitude: lon2 * 180 / M_PI)
  }
}

