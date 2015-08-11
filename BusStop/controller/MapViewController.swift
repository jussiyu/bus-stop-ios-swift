//
//  MapViewController.swift
//  Pods
//
//  Created by Jussi Yli-Urpo on 11.8.15.
//
//

import UIKit
import MapKit
import AsyncLegacy

class MapViewController: UIViewController {
  
  class StopAnnotation : MKPointAnnotation {
    
  }
  
  @IBOutlet weak var mapView: MKMapView!
  
  var userLocation: CLLocation?
  var stop: Stop?
  
  let stopReuseIdentifier = "stopPin"
  
  override func viewDidLoad() {
    super.viewDidLoad()

    if let userLocation = userLocation {
      let initialCamera = MKMapCamera(lookingAtCenterCoordinate: userLocation.coordinate, fromEyeCoordinate: userLocation.coordinate, eyeAltitude: 100)
      mapView.setCamera(initialCamera, animated: false)
    }
    if let stop = stop {
      let stopPointAnnotation = MKPointAnnotation()
      stopPointAnnotation.title = stop.name
      stopPointAnnotation.coordinate = stop.location.coordinate
      mapView.addAnnotation(stopPointAnnotation)
      
      let stopCamera = MKMapCamera(lookingAtCenterCoordinate: stop.location.coordinate, fromEyeCoordinate: stop.location.coordinate, eyeAltitude: 1000)
      Async.main(after: 1) {
        self.mapView.setCamera(stopCamera, animated: true)
      }
    }
    
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

extension MapViewController : MKMapViewDelegate {
  
  func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
    
    if annotation is MKUserLocation {
      return nil
    }
    
    return MKPinAnnotationView(annotation: annotation, reuseIdentifier: stopReuseIdentifier)
  }
  
}