import Foundation
import AVFoundation
import MLX
import MLXAudioSTT
import SayseeCore

/// MLX model execution stays off the main actor and is serialized across takes.
private final class QwenModelBox:@unchecked Sendable {let model:Qwen3ASRModel;init(_ model:Qwen3ASRModel){self.model=model}}
private actor QwenRecognizer {
 private var loading:Task<QwenModelBox,Error>?
 private var model:Qwen3ASRModel?
 func prepare(directory:URL) async throws {
  if model != nil {return}
  if let loading=loading {model=try await loading.value.model;return}
  let task=Task {QwenModelBox(try await Qwen3ASRModel.fromModelDirectory(directory))};loading=task
  do {model=try await task.value.model;loading=nil} catch {loading=nil;throw error}
 }
 func transcribe(_ samples:[Float],valid:@Sendable ()->Bool) throws -> String {
  guard let model=model else {throw SayseeError.message("语音模型尚未准备好。")}
  var parts=[String]()
  // Bound encoder memory and assign a fresh token budget to every long-take chunk.
  let step=16000*30,tokenLimit=2048
  for offset in stride(from:0,to:samples.count,by:step) {
   guard valid(),!Task.isCancelled else {throw CancellationError()}
   let output=model.generate(audio:MLXArray(Array(samples[offset..<min(samples.count,offset+step)])),maxTokens:tokenLimit,temperature:0,language:nil)
   guard valid(),!Task.isCancelled else {throw CancellationError()}
   guard output.generationTokens<tokenLimit else {throw SayseeError.message("语音识别达到长度上限，请缩短录音后重试。")}
   parts.append(output.text);Memory.clearCache()
  }
  return parts.joined(separator:" ").trimmingCharacters(in:.whitespacesAndNewlines)
 }
}

final class NativeDecoder:@unchecked Sendable {
 private let buffer=PCMRecordingBuffer()
 private let recognizer=QwenRecognizer()
 private let lock=NSLock()
 private var current:UUID?
 private var chunks=[Task<String,Error>]()
 var onFailure:((String)->Void)?
 static var modelDirectory:String {
  if let path=ProcessInfo.processInfo.environment["SAYSEE_MODEL_DIR"] {return path}
  return Bundle.main.resourceURL!.appendingPathComponent("Models/qwen3-asr-1.7b-6bit").path
 }
 func begin(sessionID:UUID) async throws {
  lock.withLock {chunks.forEach{$0.cancel()};chunks=[];current=sessionID;buffer.begin(sessionID)}
  let tick=DiagnosticLog.now()
  do {
   try await recognizer.prepare(directory:URL(fileURLWithPath:Self.modelDirectory))
   guard buffer.isCurrent(sessionID),!Task.isCancelled else {throw CancellationError()}
   DiagnosticLog.emit("stt_model_ready",session:sessionID,since:tick,metadata:["model":"Qwen3-ASR-1.7B-6bit","backend":"mlx_metal"])
  } catch {buffer.cancel(session:sessionID);throw error}
 }
 func accept(_ samples:[Float],rate:Int32,session:UUID?=nil) {
  lock.withLock {
   guard let id=session ?? current,current==id,
         buffer.append(samples,sampleRate:Int(rate),session:id) else {return}
   // Keep the same 30-second boundaries as the previous full-file decoder.
   // Only the execution time changes: completed blocks run while capture continues.
   for chunk in buffer.drainCompletedChunks(seconds:30,session:id) {
    let recognizer=self.recognizer,buffer=self.buffer
    chunks.append(Task.detached(priority:.userInitiated) {
     guard buffer.isCurrent(id),!Task.isCancelled else {throw CancellationError()}
     let tick=DiagnosticLog.now()
     let pcm=try PCMResampler.to16k(chunk.samples,sampleRate:chunk.sampleRate)
     let text=try await recognizer.transcribe(pcm,valid:{buffer.isCurrent(id)})
     guard buffer.isCurrent(id),!Task.isCancelled else {throw CancellationError()}
     DiagnosticLog.emit("stt_chunk_complete",session:id,since:tick,metadata:["audio_ms":String(format:"%.1f",chunk.duration*1000),"backend":"mlx_metal"])
     return text
    })
   }
  }
 }
 func finish() async throws -> String {
  let (id,recording,pending,duration)=try lock.withLock {() throws -> (UUID,PCMRecording,[Task<String,Error>],Double) in
   guard let id=current else {throw CancellationError()}
   let duration=self.buffer.duration(session:id)
   do {return (id,try self.buffer.take(id),chunks,duration)}
   catch {chunks.forEach{$0.cancel()};chunks=[];self.buffer.cancel(session:id);throw error}
  }
  let tick=DiagnosticLog.now(),recognizer=self.recognizer,buffer=self.buffer
  defer {lock.withLock {if current==id {chunks=[]}}}
  return try await withTaskCancellationHandler {
   do {
    var parts=[String]()
    // Task values are collected in capture order even if scheduling order differs.
    for chunk in pending {parts.append(try await chunk.value)}
    guard buffer.isCurrent(id),!Task.isCancelled else {throw CancellationError()}
    if !recording.samples.isEmpty {
     let samples=try PCMResampler.to16k(recording.samples,sampleRate:recording.sampleRate)
     DiagnosticLog.emit("stt_audio_ready",session:id,since:tick,metadata:["audio_ms":String(format:"%.1f",recording.duration*1000)])
     parts.append(try await recognizer.transcribe(samples,valid:{buffer.isCurrent(id)}))
    }
    guard buffer.isCurrent(id),!Task.isCancelled else {throw CancellationError()}
    DiagnosticLog.emit("stt_finalize",session:id,since:tick,metadata:["model":"Qwen3-ASR-1.7B-6bit","audio_ms":String(format:"%.1f",duration*1000),"rtf":String(format:"%.4f",(DiagnosticLog.now()-tick)/max(duration,0.001))])
    return parts.joined(separator:" ").trimmingCharacters(in:.whitespacesAndNewlines)
   } catch {
    pending.forEach{$0.cancel()};buffer.cancel(session:id);throw error
   }
  } onCancel:{pending.forEach{$0.cancel()};buffer.cancel(session:id)}
 }
 func cancel() {lock.withLock {chunks.forEach{$0.cancel()};chunks=[];buffer.cancel();current=nil}}
}
