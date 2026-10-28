import Foundation
public struct PCMRecording:Sendable {
 public let samples:[Float]
 public let sampleRate:Int
 public var duration:Double {Double(samples.count)/Double(sampleRate)}
}
/// In-memory take isolation; callbacks from cancelled engines are rejected.
public final class PCMRecordingBuffer:@unchecked Sendable {
 private let lock=NSLock()
 private let maxDuration:Double
 private var session:UUID?,accepting=false,samples=[Float](),rate=0,totalSamples=0,failure:Error?
 public init(maxDuration:Double=300) {self.maxDuration=maxDuration}
 public func begin(_ id:UUID) {lock.lock();defer{lock.unlock()};session=id;accepting=true;samples=[];rate=0;totalSamples=0;failure=nil}
 public func isCurrent(_ id:UUID)->Bool {lock.lock();defer{lock.unlock()};return session==id}
 @discardableResult public func append(_ input:[Float],sampleRate:Int,session id:UUID)->Bool {
  lock.lock();defer{lock.unlock()}
  guard session==id,accepting else {return false}
  guard sampleRate>=8000,sampleRate<=192000,(rate==0 || rate==sampleRate),input.allSatisfy({$0.isFinite}) else {
   failure=SayseeError.message("麦克风音频格式发生变化或包含无效采样，请重新录音。");accepting=false;return false
  }
  rate=sampleRate
  guard Double(totalSamples+input.count)<=Double(rate)*maxDuration else {
   failure=SayseeError.message("录音超过五分钟限制，请缩短后重新录音。");accepting=false;return false
  }
  samples.append(contentsOf:input);totalSamples+=input.count;return true
 }
 /// Consume only complete blocks; take() later returns the unconsumed tail.
 public func drainCompletedChunks(seconds:Double,session id:UUID)->[PCMRecording] {
  lock.lock();defer{lock.unlock()}
  guard session==id,accepting,rate>0,seconds.isFinite,seconds>0,
        seconds<=maxDuration else {return []}
  let size=Int(Double(rate)*seconds)
  guard size>0,samples.count>=size else {return []}
  let count=samples.count/size
  let chunks=(0..<count).map {i in PCMRecording(samples:Array(samples[(i*size)..<((i+1)*size)]),sampleRate:rate)}
  samples.removeFirst(count*size)
  return chunks
 }
 public func duration(session id:UUID)->Double {
  lock.lock();defer{lock.unlock()};return session==id && rate>0 ? Double(totalSamples)/Double(rate):0
 }
 public func take(_ id:UUID) throws -> PCMRecording {
  lock.lock();defer{lock.unlock()}
  guard session==id else {throw CancellationError()}
  if let failure=failure {throw failure}
  guard accepting else {throw CancellationError()}
  accepting=false;let result=PCMRecording(samples:samples,sampleRate:rate==0 ? 16000:rate);samples=[];return result
 }
 public func cancel(session id:UUID?=nil) {
  lock.lock();defer{lock.unlock()};guard id==nil || session==id else {return};session=nil;accepting=false;samples=[];failure=nil
 }
}
