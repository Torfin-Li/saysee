import XCTest
@testable import SayseeCore
final class PCMRecordingTests:XCTestCase {
 func testCancelledAndStaleMicrophoneCallbacksCannotPolluteNewTake() throws {
  let buffer=PCMRecordingBuffer(maxDuration:1),old=UUID(),next=UUID()
  buffer.begin(old);XCTAssertTrue(buffer.append([0.2],sampleRate:16000,session:old));buffer.cancel()
  buffer.begin(next);buffer.cancel(session:old);XCTAssertFalse(buffer.append([0.9],sampleRate:16000,session:old))
  XCTAssertTrue(buffer.append([0.4],sampleRate:16000,session:next))
  XCTAssertThrowsError(try buffer.take(old));XCTAssertEqual(try buffer.take(next).samples,[0.4])
 }
 func testDurationBoundNeverSilentlyTruncatesAudio() {
  let buffer=PCMRecordingBuffer(maxDuration:0.01),id=UUID();buffer.begin(id)
  XCTAssertFalse(buffer.append([Float](repeating:0,count:161),sampleRate:16000,session:id))
  XCTAssertThrowsError(try buffer.take(id))
 }
 func testInvalidSamplesAndRateChangesAreReported() {
  for samples in [[Float.nan],[Float.infinity]] {
   let b=PCMRecordingBuffer(),id=UUID();b.begin(id);XCTAssertFalse(b.append(samples,sampleRate:16000,session:id));XCTAssertThrowsError(try b.take(id))
  }
  let b=PCMRecordingBuffer(),id=UUID();b.begin(id)
  XCTAssertTrue(b.append([0.1],sampleRate:48000,session:id));XCTAssertFalse(b.append([0.2],sampleRate:44100,session:id));XCTAssertThrowsError(try b.take(id))
 }
 func testTakeEndsCaptureAndPreservesSampleRate() throws {
  let b=PCMRecordingBuffer(),id=UUID();b.begin(id);_ = b.append([0.1,0.2],sampleRate:48000,session:id)
  let recording=try b.take(id);XCTAssertEqual(recording.sampleRate,48000);XCTAssertEqual(recording.samples.count,2)
  XCTAssertFalse(b.append([0.3],sampleRate:48000,session:id));XCTAssertThrowsError(try b.take(id))
 }
 func testCompletedChunksAndTailPreserveEverySampleInOrder() throws {
  let b=PCMRecordingBuffer(),id=UUID();b.begin(id)
  let input=(0..<20001).map {Float($0)}
  XCTAssertTrue(b.append(Array(input.prefix(7999)),sampleRate:8000,session:id))
  XCTAssertTrue(b.drainCompletedChunks(seconds:1,session:id).isEmpty)
  XCTAssertTrue(b.append(Array(input.dropFirst(7999)),sampleRate:8000,session:id))
  let chunks=b.drainCompletedChunks(seconds:1,session:id)
  XCTAssertEqual(chunks.map { $0.samples.count },[8000,8000])
  XCTAssertTrue(b.drainCompletedChunks(seconds:1,session:id).isEmpty)
  let tail=try b.take(id)
  XCTAssertEqual(chunks.flatMap { $0.samples }+tail.samples,input)
 }
 func testDrainingDoesNotResetDurationLimitAndRejectsStaleSessions() throws {
  let b=PCMRecordingBuffer(maxDuration:1.5),old=UUID(),next=UUID();b.begin(old)
  XCTAssertTrue(b.append([Float](repeating:0,count:8000),sampleRate:8000,session:old))
  XCTAssertEqual(b.drainCompletedChunks(seconds:1,session:old).count,1)
  XCTAssertFalse(b.append([Float](repeating:0,count:4001),sampleRate:8000,session:old))
  XCTAssertThrowsError(try b.take(old))
  b.begin(next);XCTAssertTrue(b.append([Float](repeating:0.5,count:8000),sampleRate:8000,session:next))
  XCTAssertTrue(b.drainCompletedChunks(seconds:1,session:old).isEmpty)
  XCTAssertEqual(try b.take(next).samples.count,8000)
 }

}
