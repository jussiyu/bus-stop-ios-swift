BusStop for iOS
========================

BusStop is an iOS application for tracking your target bus stop while travelling
in Tampere area busses in Finland.

<p align="center" >
<img src="img/screenshot-mainscreen.png?raw=true" width="266" alt="Main screen"/>
<img src="img/screenshot-selected-stop.png?raw=true" width="266" alt="Selected stop view"/>
</p>

Application has been maily developed as way to learn to code in Swift. There are
currenly no plans to release it as a binary or via App Store.

##Compiling

Application has been developed on Xcode 7.0.1 and Swift 2.0.  The deployment
target is set to iOS8.0.  

A Swift 1.2 compatible version of the application is available on `Swift1.2`
brach.

### Dependencies

Application depends on the following CocoaPods:

* [SwiftyJSON](https://cocoapods.org/pods/SwiftyJSON)
* [MediumProgressView](https://cocoapods.org/pods/MediumProgressView) (currently private fork)
* [ReachabilitySwift](https://cocoapods.org/pods/ReachabilitySwift)
* [XCGLogger](https://cocoapods.org/pods/XCGLogger)
* [Async](https://github.com/JohnCoates/Async.git)
* [TaskQueue](https://cocoapods.org/pods/TaskQueue) (private fork)
* [RealmSwift](https://cocoapods.org/pods/RealmSwift)

See [Podfile](Podfile) for specific versions ranges and
[Podfile.lock](Podfile.lock) for exact versions used in development and testing.

## How to compile

Pods are not included so therefore you need to fetch them by running `pod
install` on a commandline inside the root `BusStop` folder.

### Commandline build

Compile application by issueing `xcodebuild -workspace BusStop.xcworkspace -scheme BusStop` on the commandline.

### Xcode build

Open _workspace.xcworkspace_ in Xcode and Build or Run _BusStop_ scheme.

## How to run tests

In Xcode select _BustStopUnitTests_ scheme to run unit test on simulator.
Alternative run tests on command line with command something like this:

    xcodebuild -workspace BusStop.xcworkspace -scheme BusStopUnitTests -destination
    'platform=iOS Simulator,name=iPhone 6s,OS=9.0' test

(Please note that if there are multiple simulators with the same name, you need to [specify
the simulator id
instead](https://developer.apple.com/library/ios/technotes/tn2339/_index.html#//apple_ref/doc/uid/DTS40014588-CH1-HOW_DO_I_RUN_UNIT_TESTS_IN_OS_X_AND_IOS_FROM_THE_COMMAND_LINE_))

## How to use the application

1. After you have entered the bus, open application
1. Scroll how the stop list until you see the stop you are planning on hopping
   off and tap the stop
1. The selected stop is show and the stop tracking is activated. You can read
   the number of stops until you stop and estimated time until your bus will
   arrive on it.
1. Either keep app open, switch to another app, or lock the phone and put it
   away
1. Audible and visual notification is given when your selected stop is the next
   one. You can tap the notification to re-launch the app.

### Refresh

Application loads bus data from network once when applications is opened (i.e.
becomes active).  After that data is not automatically refreshed until a stop
is selected. Once the stop is selected, data is refresh at least once per 10
seconds and more often as the selected stop gets closer.  Pull down the stop
list to manually refresh stop for the selected bus. Tap refresh button on the
toolbar to manually refresh of the vehicles.

### Map view

Tap _i_ button next to stop name to open stop in map view.

<img src="img/screenshot-map.png?raw=true" width="266" alt="Map view"/>
## Licenses

BusStop uses Tampere Public Transport open data via [Journeys
API](http://wiki.itsfactory.fi/index.php/Journeys_API).

Application uses content owned by [Tampere
city](http://www.tampere.fi/tampereinfo/avoindata.html).

## TODO

* Add unit tests for remaining model classes
* Add functional test for main controllers and API classes
* Reload bus stop data periodically (currently loaded only on the first
  start)
* Show favourite stops on the top of the stop list

## Licence

    Copyright (c) 2015 Solipaste Oy
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

