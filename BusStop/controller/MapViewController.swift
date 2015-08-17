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


import UIKit
import MapKit
import AsyncLegacy

class MapViewController: UIViewController {
  
  class StopAnnotation : MKPointAnnotation {
    var selectedStop = false
  }
  
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var showUserLocationButtonItem: UIBarButtonItem!
  
  var userLocation: CLLocation?
  var selectedStop: Stop?
  var selectedVehicle: VehicleActivity?
  
  let stopReuseIdentifier = "stopPin"

  let stopDBManager = StopDBManager.sharedInstance

  override func viewDidLoad() {
    super.viewDidLoad()

    if let userLocation = userLocation {
      let initialCamera = MKMapCamera(lookingAtCenterCoordinate: userLocation.coordinate, fromEyeCoordinate: userLocation.coordinate, eyeAltitude: 100)
      mapView.setCamera(initialCamera, animated: false)
    }
    
    if let selectedVehicle = selectedVehicle {
      for stop in selectedVehicle.stops {
        if let stop = stopDBManager.stopWithId(stop.id) where stop.id != selectedStop?.id {
          let stopPointAnnotation = StopAnnotation()
          stopPointAnnotation.title = "\(stop.name) (\(stop.id))"
          stopPointAnnotation.coordinate = stop.location.coordinate
          mapView.addAnnotation(stopPointAnnotation)
          mapView.selectAnnotation(stopPointAnnotation, animated: true)
        }
      }
    }
    if let stop = selectedStop {
      let stopPointAnnotation = StopAnnotation()
      stopPointAnnotation.selectedStop = true
      stopPointAnnotation.title = "\(stop.name) (\(stop.id))"
      stopPointAnnotation.coordinate = stop.location.coordinate
      mapView.addAnnotation(stopPointAnnotation)
      mapView.selectAnnotation(stopPointAnnotation, animated: true)
      
      let stopCamera = MKMapCamera(lookingAtCenterCoordinate: stop.location.coordinate, fromEyeCoordinate: stop.location.coordinate, eyeAltitude: 1000)
      self.mapView.setCamera(stopCamera, animated: true)
    }
    
    showUserLocationButtonItem.enabled = userLocation != nil ? true : false
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func showUserLocation(sender: AnyObject) {
    if let userLocation = userLocation {
      let userCamera = MKMapCamera(lookingAtCenterCoordinate: userLocation.coordinate, fromEyeCoordinate: userLocation.coordinate, eyeAltitude: 1000)
      self.mapView.setCamera(userCamera, animated: true)
    }
  }
}

extension MapViewController : MKMapViewDelegate {
  
  func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
    
    if annotation is MKUserLocation {
      return nil
    }
    var view: MKPinAnnotationView! = mapView.dequeueReusableAnnotationViewWithIdentifier(stopReuseIdentifier) as? MKPinAnnotationView
    if view == nil {
      view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: stopReuseIdentifier)
      view.canShowCallout = true
    }

    if let annotation = annotation as? StopAnnotation where annotation.selectedStop {
      view.pinColor = MKPinAnnotationColor.Red
    } else {
      view.pinColor = MKPinAnnotationColor.Purple
    }
    return view
  }
}
