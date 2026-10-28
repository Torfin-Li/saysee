import XCTest
@testable import SayseeCore
final class DiagnosticsTests:XCTestCase {
 func testLogContainsTimingButDropsTextAndSecrets() throws {
  let data=try DiagnosticLog.encode(stage:"llm_complete",session:"test",durationMs:123.4,elapsedMs:200,metadata:["model":"test-model","input_chars":"42","transcript":"private speech","token":"secret"])
  let json=try JSONSerialization.jsonObject(with:data) as! [String:Any]
  XCTAssertEqual(json["stage"] as? String,"llm_complete");XCTAssertEqual(json["duration_ms"] as? Double,123.4)
  XCTAssertNil(json["transcript"]);XCTAssertNil(json["token"]);XCTAssertEqual(json["input_chars"] as? String,"42")
 }
 func testSecondProcessLockIsRejectedAndReleased() throws {
  let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer {try? FileManager.default.removeItem(at:url)}
  var first:ProcessLock?=try ProcessLock(url:url);XCTAssertNotNil(first)
  XCTAssertThrowsError(try ProcessLock(url:url));first=nil
  XCTAssertNoThrow(try ProcessLock(url:url))
 }
}
