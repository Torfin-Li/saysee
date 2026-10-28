import XCTest
@testable import SayseeCore
final class PCMResamplerTests:XCTestCase {
 func testConvertsMicrophoneRateAndPreservesSpeechBand() throws {
  let input=(0..<48000).map{Float(0.6*sin(2*Double.pi*1000*Double($0)/48000))}
  let output=try PCMResampler.to16k(input,sampleRate:48000)
  XCTAssertEqual(output.count,16000,accuracy:32)
  XCTAssertTrue(output.allSatisfy{$0.isFinite})
  let rms=sqrt(output.map{Double($0)*Double($0)}.reduce(0,+)/Double(output.count))
  XCTAssertGreaterThan(rms,0.35);XCTAssertLessThan(rms,0.5)
 }
 func testDownsamplingRejectsOutOfBandAliasing() throws {
  let input=(0..<48000).map{Float(0.6*sin(2*Double.pi*12000*Double($0)/48000))}
  let output=try PCMResampler.to16k(input,sampleRate:48000)
  let rms=sqrt(output.map{Double($0)*Double($0)}.reduce(0,+)/Double(output.count))
  XCTAssertLessThan(rms,0.05)
 }
 func testEmptyAndAlready16kAudio() throws {
  XCTAssertTrue(try PCMResampler.to16k([],sampleRate:48000).isEmpty)
  XCTAssertEqual(try PCMResampler.to16k([0.1,0.2],sampleRate:16000),[0.1,0.2])
 }
}
