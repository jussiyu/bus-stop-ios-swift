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
import SwiftyJSON
import Async

// Common functionality
class APIDelegateBase: APIControllerDelegate {
  let ref: MainViewController
  init(ref: MainViewController) {
    self.ref = ref
  }
  
  func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
  }
  
  func didReceiveError(urlerror: NSError, next: ApiControllerDelegateNextTask?) {
    self.ref.initialRefreshTaskQueue?.removeAll()
    next?("URL error \(urlerror)")
  }
  
  func handleError(results: JSON, next: ApiControllerDelegateNextTask?) {
    Async.main {
      let errorTitle = results["data"]["title"] ?? "unknown error"
      let errorMessage = results["data"]["message"] ?? "unknown details"
      let alertController = UIAlertController(title: "Network error", message:
        "Failed to read data from network. The detailed error was:\n \"\(errorTitle): \(errorMessage)\"", preferredStyle: UIAlertControllerStyle.Alert)
      alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
      self.ref.presentViewController(alertController, animated: true, completion: nil)
      self.ref.initialRefreshTaskQueue?.removeAll()
      next?("JSON error")
    }
  }
}

// API call specific delegates
class VehicleDelegate :APIDelegateBase {
  override func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
    if results["status"] == "success" {
      self.ref.vehicles = Vehicles(fromJSON: results["body"])
      next?(nil)
    } else { // status != success
      handleError(results, next: next)
    }
  }
}

class VehicleStopsDelegate :APIDelegateBase {
  override func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
    if results["status"] == "success" {
      self.ref.vehicles.setStopsFromJSON(results["body"])
      self.ref.vehicles.setLocationsFromJSON(results["body"])
      Async.main {
        self.ref.stopDelegate?.reloadStops()
        UIView.animateWithDuration(0.3) {
          self.ref.stopTableContainerView.hidden = false
        }
        next?(nil)
      }
    } else { // status != success
      handleError(results, next: next)
    }
  }
}

class StopsDelegate: APIDelegateBase {
  
  override func didReceiveAPIResults(results: JSON, next: ApiControllerDelegateNextTask?) {
    if results["status"] == "success" {
      self.ref.stopDBManager.initFromJSON(results["body"])
      next?(nil)
    } else { // status != success
      handleError(results, next: next)
    }
  }
}

