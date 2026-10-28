import XCTest
@testable import SayseeCore
final class AudioActivityDetectorTests:XCTestCase {
 private func tone(_ seconds:Double,amplitude:Float)->[Float] {
  (0..<Int(seconds*16000)).map {amplitude*Float(sin(Double($0)*2*Double.pi*440/16000))}
 }
 func testSilenceAndLowLevelNoiseStayStill() {
  var d=AudioActivityDetector()
  d.consume([Float](repeating:0,count:16000),sampleRate:16000)
  XCTAssertFalse(d.isActive)
  d.consume(tone(1,amplitude:0.001),sampleRate:16000)
  XCTAssertFalse(d.isActive)
 }
 func testSpeechStartsAnimationAndPauseStopsIt() {
  var d=AudioActivityDetector()
  d.consume(tone(0.10,amplitude:0.05),sampleRate:16000)
  XCTAssertTrue(d.isActive)
  d.consume([Float](repeating:0,count:1600),sampleRate:16000)
  XCTAssertTrue(d.isActive) // bridge small gaps within a phrase
  d.consume([Float](repeating:0,count:3200),sampleRate:16000)
  XCTAssertFalse(d.isActive)
 }
 func testBriefClickDoesNotStartAnimationAndResetClearsOldActivity() {
  var d=AudioActivityDetector()
  d.consume(tone(0.02,amplitude:0.5),sampleRate:16000)
  d.consume([Float](repeating:0,count:3200),sampleRate:16000)
  XCTAssertFalse(d.isActive)
  d.consume(tone(0.10,amplitude:0.05),sampleRate:16000)
  XCTAssertTrue(d.isActive)
  d.reset();XCTAssertFalse(d.isActive)
 }
 func testAnalysisIsIndependentOfTapBufferSize() {
  let input=tone(0.2,amplitude:0.05)+[Float](repeating:0,count:4800)
  var whole=AudioActivityDetector(),split=AudioActivityDetector()
  whole.consume(input,sampleRate:16000)
  for offset in stride(from:0,to:input.count,by:137) {
   split.consume(Array(input[offset..<min(input.count,offset+137)]),sampleRate:16000)
  }
  XCTAssertEqual(whole.isActive,split.isActive);XCTAssertFalse(split.isActive)
 }
}
