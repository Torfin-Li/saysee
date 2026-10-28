import Foundation
import AVFoundation
import SayseeCore

/// Explicit file-only developer checks. Never starts a microphone or pastes text.
enum STTValidation {
 static func audio(_ path:String) throws -> ([Float],Int32) {
  let file=try AVAudioFile(forReading:URL(fileURLWithPath:path)),format=file.processingFormat
  guard file.length>0,Double(file.length)/format.sampleRate<=300,
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(file.length)) else {throw SayseeError.message("测试音频需为五分钟以内的非空文件。")}
  try file.read(into:buffer)
  guard let channels=buffer.floatChannelData else {throw SayseeError.message("测试音频必须为浮点 PCM。")}
  let count=Int(buffer.frameLength);var mono=[Float](repeating:0,count:count)
  for c in 0..<Int(format.channelCount) {for i in 0..<count {mono[i]+=channels[c][i]/Float(format.channelCount)}}
  return (mono,Int32(format.sampleRate))
 }
 /// Feed a file at capture speed to verify that inference overlaps recording.
 static func paced(_ path:String) async throws {
  let (samples,rate)=try audio(path),decoder=NativeDecoder(),id=UUID()
  try await decoder.begin(sessionID:id)
  let start=DiagnosticLog.now(),step=Int(rate)
  for offset in stride(from:0,to:samples.count,by:step) {
   let end=min(samples.count,offset+step)
   decoder.accept(Array(samples[offset..<end]),rate:rate,session:id)
   let deadline=start+Double(end)/Double(rate)
   let remaining=deadline-DiagnosticLog.now()
   if remaining>0 {try await Task.sleep(nanoseconds:UInt64(remaining*1_000_000_000))}
  }
  let stop=DiagnosticLog.now()
  DiagnosticLog.emit("validation_capture_stopped",session:id)
  let text=try await decoder.finish()
  let data=try JSONSerialization.data(withJSONObject:["file":URL(fileURLWithPath:path).lastPathComponent,"post_stop_ms":DiagnosticLog.milliseconds(since:stop),"audio_ms":Double(samples.count)/Double(rate)*1000,"text":text],options:[.sortedKeys])
  print(String(decoding:data,as:UTF8.self))
 }
 static func run(_ paths:[String]) async throws {
  guard let first=paths.first else {throw SayseeError.message("请指定测试音频文件。")}
  let decoder=NativeDecoder()
  for path in paths {
   let (samples,rate)=try audio(path)
   for run in 1...2 {
    let id=UUID();try await decoder.begin(sessionID:id)
    decoder.accept(samples,rate:rate,session:id)
    let tick=DiagnosticLog.now();let text=try await decoder.finish()
    let data=try JSONSerialization.data(withJSONObject:["file":URL(fileURLWithPath:path).lastPathComponent,"run":run,"duration_ms":DiagnosticLog.milliseconds(since:tick),"text":text],options:[.sortedKeys])
    print(String(decoding:data,as:UTF8.self))
   }
  }
  let (samples,rate)=try audio(first),old=UUID();try await decoder.begin(sessionID:old);decoder.accept(samples,rate:rate,session:old)
  let job=Task {try await decoder.finish()}
  try await Task.sleep(nanoseconds:200_000_000)
  let tick=DiagnosticLog.now();decoder.cancel();job.cancel()
  do {_ = try await job.value;throw SayseeError.message("取消的识别不应产生可交付结果。")}
  catch is CancellationError {}
  let next=UUID();try await decoder.begin(sessionID:next);decoder.accept(samples,rate:rate,session:next)
  let text=try await decoder.finish();guard !text.isEmpty else {throw SayseeError.message("取消后的新会话识别失败。")}
  print("{\"cancelled_result_rejected\":true,\"next_take_characters\":\(text.count),\"cancel_to_next_result_ms\":\(DiagnosticLog.milliseconds(since:tick))}")
 }
}
