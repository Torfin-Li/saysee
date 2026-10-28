import XCTest
@testable import SayseeCore
final class CoreTests: XCTestCase {
 func testCancelledSessionCannotPublish() {
  var gate = SessionGate(); let old = gate.begin(); gate.cancel(); XCTAssertFalse(gate.accepts(old))
  let next = gate.begin(); XCTAssertFalse(gate.accepts(old)); XCTAssertTrue(gate.accepts(next))
 }
 func testBlockingDeepSeekRequest() throws {
  let c = RewriteConfiguration(model:"deepseek-flash")
  let request = try RewriteClient.request(text: "明天开会", configuration: c, token: "test")
  let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
  XCTAssertEqual(json["stream"] as? Bool, false); XCTAssertEqual(request.url?.host, "api.deepseek.com")
  XCTAssertEqual((json["thinking"] as? [String:String])?["type"], "disabled")
 }
 func testEmptyTranscriptRejected() {
  XCTAssertThrowsError(try RewriteClient.request(text: " \n", configuration: .standard, token: "test"))
 }
 func testEmptyOutputRejected() {
  XCTAssertThrowsError(try RewriteClient.parse(Data("{\"choices\":[{\"message\":{\"content\":\"\"}}]}".utf8)))
 }
}
