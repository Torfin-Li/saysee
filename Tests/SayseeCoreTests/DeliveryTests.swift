import XCTest
@testable import SayseeCore
final class DeliveryTests:XCTestCase {
 func testWritableNonTextControlsNeverReceivePaste() {
  XCTAssertFalse(TextTargetPolicy.accepts(role:"AXSlider",subrole:nil,writable:true))
  XCTAssertFalse(TextTargetPolicy.accepts(role:"AXCheckBox",subrole:nil,writable:true))
  XCTAssertFalse(TextTargetPolicy.accepts(role:"AXTextField",subrole:"AXSecureTextField",writable:true))
  XCTAssertFalse(TextTargetPolicy.accepts(role:"AXTextArea",subrole:nil,writable:false))
  XCTAssertTrue(TextTargetPolicy.accepts(role:"AXTextArea",subrole:nil,writable:true))
  XCTAssertTrue(TextTargetPolicy.accepts(role:"AXTextField",subrole:"AXSearchField",writable:true))
 }
 func testWindowAndContainerNeverImplyEditableInput() {
  for role in ["AXWindow","AXApplication","AXGroup","AXWebArea"] {
   XCTAssertFalse(TextTargetPolicy.accepts(role:role,subrole:nil,writable:true))
  }
 }
}
