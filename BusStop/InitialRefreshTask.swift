//
//  InitialRefreshTask.swift
//
//
//  Created by Jussi Yli-Urpo on 20.7.15.
//
//

import Foundation
import TaskQueue
import XCGLogger

//func IntitialRefreshTask() -> TaskQueue {
//  let q = TaskQueue()
//  
//  q.tasks +=! {
//    log.info("Task: show progress")
//    
//  }
//  
//  q.tasks +=~ { next in
//    log.info("Task: load stop data")
//    api.getStops( next )
//  }
//  
//  q.tasks +=~ { next in
//    log.info("Task: load vehicle headers")
//    api.getVehicleActivityHeaders( next )
//  }
//
//  q.tasks +=! {
//    log.info("Task: show vehicle headers")
//    
//  }
//  
//  q.tasks +=~ {
//    log.info("Task: wait for location")
//    // get closes vehicle
//  }
//  
//  q.tasks +=! {
//    log.info("Task: show closest vehicle headers => load stops for the current vehicle")
//    api.getVehicleActivityStopsForVehicle("")
//  }
//  
//  return q
//}
