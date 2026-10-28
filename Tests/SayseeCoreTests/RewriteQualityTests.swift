import XCTest
@testable import SayseeCore

final class RewriteQualityTests:XCTestCase {
 func testOnlyDeepSeekTextRequestWithDisabledThinking() throws {
  let request=try RewriteClient.request(text:"不要发布",configuration:.init(model:"deepseek-flash"),token:"test")
  let body=try XCTUnwrap(JSONSerialization.jsonObject(with:XCTUnwrap(request.httpBody)) as? [String:Any])
  XCTAssertEqual(request.url?.absoluteString,"https://api.deepseek.com/chat/completions")
  XCTAssertEqual(body["stream"] as? Bool,false)
  XCTAssertEqual((body["thinking"] as? [String:Any])?["type"] as? String,"disabled")
  XCTAssertEqual((body["messages"] as? [[String:String]])?.last?["content"],"不要发布")
 }
 func testCompleteTextIsReturnedAndTruncationIsRejected() throws {
  let complete=Data(#"{"choices":[{"finish_reason":"stop","message":{"content":"  整理好了。  "}}]}"#.utf8)
  XCTAssertEqual(try RewriteClient.parse(complete),"整理好了。")
  let truncated=Data(#"{"choices":[{"finish_reason":"length","message":{"content":"未完成"}}]}"#.utf8)
  XCTAssertThrowsError(try RewriteClient.parse(truncated))
 }
 func testLegacySettingsArePurgedWithoutReadingCredentialsOrChangingModel() {
  let name="Saysee-migration-test-\(UUID())",defaults=UserDefaults(suiteName:name)!
  defer{defaults.removePersistentDomain(forName:name)}
  for key in LegacySettingsMigration.keys {defaults.set("synthetic",forKey:key)}
  defaults.set("my-model",forKey:"deepSeekModel")
  LegacySettingsMigration.remove(from:defaults)
  XCTAssertTrue(LegacySettingsMigration.keys.allSatisfy{defaults.object(forKey:$0)==nil})
  XCTAssertEqual(defaults.string(forKey:"deepSeekModel"),"my-model")
 }
}
