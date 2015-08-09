import Quick
import Nimble
import BusStop
import CoreLocation

class StopTests: QuickSpec {
    override func spec() {

    }
  
  func testInit_createsObjectWithMandatoryProperties() {
    let stop = Stop(id: "id", name: "name")
    XCTAssertEqual(stop.id, "id", "Stop created with id")
    XCTAssertEqual(stop.name, "name", "Stop created with name")
    XCTAssertEqual(stop.longitude, 0, "Stop created with zero longitude")
    XCTAssertEqual(stop.latitude, 0, "Stop created with zero latitude")
    XCTAssertEqual(stop.favorite, false, "Stop created as non-favorite")
  }
  
  func testInit_createsObjectWithAllProperties() {
    let stop = Stop(id: "id", name: "name", location: CLLocation(latitude: 10, longitude: 20))
    XCTAssertEqual(stop.id, "id", "Stop created with id")
    XCTAssertEqual(stop.name, "name", "Stop created with name")
    XCTAssertEqual(stop.longitude, 10, "Stop created with non-zero longitude")
    XCTAssertEqual(stop.latitude, 20, "Stop created with non-zero latitude")
    XCTAssertEqual(stop.favorite, false, "Stop created as non-favorite")
  }
}
