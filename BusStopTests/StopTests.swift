import Quick
import Nimble
import CoreLocation
import XCGLogger
import RealmSwift


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
        
        it("to be from invalid distance to anywhere") {
          let anyLocation = CLLocation(latitude: -23, longitude: 61)
          expect(stop.distanceFromUserLocation(anyLocation)).to(equal("--"))
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
        let location = CLLocation(latitude: -23, longitude: 61)
        beforeEach {
          stop = Stop(id: "id", name: "name", location: location)
        }
        
        it("of 0 meters") {
          let sameLocation = location
          expect(stop.distanceFromUserLocation(sameLocation)).to(equal("Exactly at your location"))
        }
        
        it("of a lot of kilometers") {
          let differentLocation = CLLocation(latitude: -23, longitude: 62)
          expect(stop.distanceFromUserLocation(differentLocation)).to(contain(" km(s) from your location"))
        }
        
        it("of few meters") {
          let anotherCoordinates = location.coordinateWithDirection(40.0, distance: 50)
          let differentLocation = CLLocation(latitude: anotherCoordinates.latitude, longitude: anotherCoordinates.longitude)
          expect(stop.distanceFromUserLocation(differentLocation)).to(contain("50 meter(s) from your location"))
        }
        
        it("to invalid distance") {
          let invalidLocation = CLLocation()
          expect(stop.distanceFromUserLocation(invalidLocation)).to(equal("--"))
        }
      }
    }
    
    describe("A stop added to database") {
      beforeSuite {
        setUpDatabase()
        Realm().write {
          Realm().deleteAll()
        }
      }
      
      var stop: Stop!
      beforeEach {
        stop = Stop(id: "9999", name: "myname", location: CLLocation(latitude: -23, longitude: 62))
        Realm().write {
          Realm().add(stop)
        }
      }
      afterEach {
        Realm().write {
          Realm().deleteAll()
        }
      }
      
      it("can be read back from database with same propery values") {
        let stopFromDatabase = Realm().objects(Stop).first!
        expect(stopFromDatabase.id).to(equal("9999"))
        expect(stopFromDatabase.name).to(equal("myname"))
        expect(stopFromDatabase.latitude).to(equal(-23))
        expect(stopFromDatabase.longitude).to(equal(62))
        expect(stopFromDatabase.favorite).to(beFalsy())
      }

      it("can be read back from database using primary key") {
        expect(Realm().objectForPrimaryKey(Stop.self, key: "9999")).to(equal(stop))
      }
    }
    
    describe("A stop in database") {
      beforeSuite {
        setUpDatabase()
        Realm().write {
          Realm().deleteAll()
        }
      }
      
      var stop: Stop!
      beforeEach {
        stop = Stop(id: "9999", name: "myname", location: CLLocation(latitude: -23, longitude: 62))
        Realm().write {
          Realm().add(stop)
        }
      }
      afterEach {
        Realm().write {
          Realm().deleteAll()
        }
      }
      
      it("can be set as favorite") {
        Realm().write {
          stop.favorite = true
        }
        expect(Realm().objectForPrimaryKey(Stop.self, key: "9999")!.favorite).to(beTruthy())
      }
      
      it("can be renamed") {
        Realm().write {
          stop.name = "newname"
        }
        expect(Realm().objectForPrimaryKey(Stop.self, key: "9999")!.name).to(equal("newname"))
      }

      it("can be relocated") {
        Realm().write {
          stop.latitude = -22
          stop.longitude = 60
        }
        expect(Realm().objectForPrimaryKey(Stop.self, key: "9999")!.latitude).to(equal(-22))
        expect(Realm().objectForPrimaryKey(Stop.self, key: "9999")!.longitude).to(equal(60))
      }
    }
  }
}
