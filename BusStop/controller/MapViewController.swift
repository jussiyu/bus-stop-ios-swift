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
    var selectedStop = false
  }
  
  @IBOutlet weak var mapView: MKMapView!
  
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
