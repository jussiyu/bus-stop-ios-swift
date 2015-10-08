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
        deleteAllDatabaseData()
      }
      
      var stop: Stop!
      beforeEach {
        stop = Stop(id: "9999", name: "myname", location: CLLocation(latitude: -23, longitude: 62))
        try! Realm().write {
          try! Realm().add(stop)
        }
      }
      afterEach {
        deleteAllDatabaseData()
      }
      
      it("can be read back from database with same propery values") {
        let stopFromDatabase = try! Realm().objects(Stop).first!
        expect(stopFromDatabase.id).to(equal("9999"))
        expect(stopFromDatabase.name).to(equal("myname"))
        expect(stopFromDatabase.latitude).to(equal(-23))
        expect(stopFromDatabase.longitude).to(equal(62))
        expect(stopFromDatabase.favorite).to(beFalsy())
      }

      it("can be read back from database using primary key") {
        expect(try! Realm().objectForPrimaryKey(Stop.self, key: "9999")).to(equal(stop))
      }
    }
    
    describe("A stop in database") {
      beforeSuite {
        setUpDatabase()
        deleteAllDatabaseData()
      }
      
      var stop: Stop!
      beforeEach {
        stop = Stop(id: "9999", name: "myname", location: CLLocation(latitude: -23, longitude: 62))
        try! Realm().write {
          try! Realm().add(stop)
        }
      }
      
      afterEach {
        deleteAllDatabaseData()
      }
      
      it("can be set as favorite") {
        try! Realm().write {
          stop.favorite = true
        }
        let object = try! Realm().objectForPrimaryKey(Stop.self, key: "9999")
        expect(object!.favorite).to(beTruthy())
      }
      
      it("can be renamed") {
        try! Realm().write {
          stop.name = "newname"
        }
        let object = try! Realm().objectForPrimaryKey(Stop.self, key: "9999")
        expect(object!.name).to(equal("newname"))
      }

      it("can be relocated") {
        try! Realm().write {
          stop.latitude = -22
          stop.longitude = 60
        }
        let object = try! Realm().objectForPrimaryKey(Stop.self, key: "9999")
        expect(object!.latitude).to(equal(-22))
        expect(object!.longitude).to(equal(60))
      }
    }
  }
}
