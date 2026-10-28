import XCTest
@testable import SayseeCore
final class HotkeyEventTests:XCTestCase {
 func testFnDeliveredAsKeyDownAndUpTogglesOnce() {
  var key=FnGesture()
  XCTAssertFalse(key.handle(keyCode:63,kind:.down,fnFlag:false,other:false))
  XCTAssertTrue(key.handle(keyCode:63,kind:.up,fnFlag:false,other:false))
 }
 func testFnOwnKeyDownDoesNotDisqualifyFlagsGesture() {
  var key=FnGesture();_ = key.handle(keyCode:63,kind:.flags,fnFlag:true,other:false)
  _ = key.handle(keyCode:63,kind:.down,fnFlag:true,other:false)
  XCTAssertTrue(key.handle(keyCode:63,kind:.flags,fnFlag:false,other:false))
 }
 func testFnFlagOnOtherKeysCannotStartGesture() {
  var key=FnGesture();_ = key.handle(keyCode:123,kind:.flags,fnFlag:true,other:false)
  XCTAssertFalse(key.handle(keyCode:63,kind:.flags,fnFlag:false,other:false))
 }
}
