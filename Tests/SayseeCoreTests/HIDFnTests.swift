import XCTest
@testable import SayseeCore
final class HIDFnTests:XCTestCase {
 func testVendorFnWithoutQuartzFlagsTriggersOnRelease() {
  var gesture=FnGesture()
  XCTAssertEqual(gesture.handleHID(page:0xff,usage:3,value:1,other:false),false)
  XCTAssertEqual(gesture.handleHID(page:0xff,usage:3,value:0,other:false),true)
 }
 func testOrdinaryKeyAndModifiersDisqualifyChord() {
  var gesture=FnGesture();_ = gesture.handleHID(page:0xff,usage:3,value:1,other:false)
  gesture.keyDown()
  XCTAssertEqual(gesture.handleHID(page:0xff,usage:3,value:0,other:false),false)
  _ = gesture.handleHID(page:0xff,usage:3,value:1,other:true)
  XCTAssertEqual(gesture.handleHID(page:0xff,usage:3,value:0,other:false),false)
 }
 func testUnrelatedHIDAndUnpairedReleaseNeverTrigger() {
  var gesture=FnGesture()
  XCTAssertNil(gesture.handleHID(page:7,usage:3,value:1,other:false))
  XCTAssertEqual(gesture.handleHID(page:0xff,usage:3,value:0,other:false),false)
 }
}
