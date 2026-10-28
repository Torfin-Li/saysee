import XCTest
@testable import SayseeCore
final class FnGestureTests:XCTestCase {
 func testOnlyReleaseOfStandaloneFnToggles() {
  var key=FnGesture();XCTAssertFalse(key.update(fn:true,other:false));XCTAssertFalse(key.update(fn:true,other:false));XCTAssertTrue(key.update(fn:false,other:false));XCTAssertFalse(key.update(fn:false,other:false))
 }
 func testCombinationIsRejectedEvenAfterModifierIsReleased() {
  var key=FnGesture();_ = key.update(fn:true,other:false);_ = key.update(fn:true,other:true);_ = key.update(fn:true,other:false);XCTAssertFalse(key.update(fn:false,other:false))
 }
 func testFnPlusOrdinaryKeyIsRejected() {
  var key=FnGesture();_ = key.update(fn:true,other:false);key.keyDown();XCTAssertFalse(key.update(fn:false,other:false))
 }
}
