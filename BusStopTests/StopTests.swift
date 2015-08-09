import Quick
import Nimble
import CoreLocation
import XCGLogger


class StopTests: QuickSpec {
  
//  override func setUp() {
//    super.setUp()
//    setUpLog()
//  }
  override func spec() {
    beforeSuite {
      setUpLog()
    }

    describe("a new stop") {
      var stop: Stop!
      
      describe("to be created using mandatory parameters") {

        beforeEach {
          stop = Stop(id: "id", name: "name")
        }
        
        it("with id") {
          expect(stop.id).to(equal("id"))
        }

        it("with name") {
          expect(stop.name).to(equal("name"))
        }

        it("without valid latitude") {
          expect(stop.latitude).to(equal(0.0))
        }
        
        it("without valid longitude") {
          expect(stop.longitude).to(equal(0.0))
        }
      }

      describe("to be created using location") {

        beforeEach {
          stop = Stop(id: "id", name: "name", location: CLLocation(latitude: 10, longitude: 20))
        }
        
        it("with coordinate with latitude") {
          expect(stop.location.coordinate.latitude).to(equal(10))
        }
        it("with coordinate with longitude") {
          expect(stop.location.coordinate.longitude).to(equal(20))
        }
      }
    
      describe("is distance from a location") {
        var stop: Stop!
        beforeEach {
          stop = Stop(id: "id", name: "name", location: CLLocation(latitude: -23, longitude: 61))
        }
        
        it("of 0 meters") {
          let sameLocation = CLLocation(latitude: -23, longitude: 61)
          expect(stop.distanceFromUserLocation(sameLocation)).to(equal(NSLocalizedString("Exactly at your location", comment: "")))
        }
        
        it("of x meters") {
          let differentLocation = CLLocation(latitude: -23, longitude: 62)
          expect(stop.distanceFromUserLocation(differentLocation)).to(contain("from your location"))
        }
      }
    }
  }
}
