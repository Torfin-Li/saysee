import Foundation
import AVFoundation
import SayseeCore

/// Tap state is separate for each capture and synchronized independently of the UI.
private final class CaptureActivity:@unchecked Sendable {
 private let lock=NSLock()
 private var detector=AudioActivityDetector()
 func update(_ samples:[Float],rate:Double)->Bool? {
  lock.withLock {
   let before=detector.isActive
   detector.consume(samples,sampleRate:rate)
   return before==detector.isActive ? nil:detector.isActive
  }
 }
}

@MainActor final class SpeechEngine {
 private var engine: AVAudioEngine?
 private var activeSession:UUID?
 private var observer:NSObjectProtocol?
 private var captureGate=SessionGate()
 var onActivity:((Bool)->Void)?
 var onInterruption:((String)->Void)?
 let decoder=NativeDecoder()
 func start(sessionID:UUID) async throws {
  activeSession=sessionID
  let allowed=await AVCaptureDevice.requestAccess(for:.audio)
  guard allowed else { throw SayseeError.message("请在系统设置 → 隐私与安全性 → 麦克风中允许 Saysee。") }
  try Task.checkCancellation();try await decoder.begin(sessionID:sessionID);try Task.checkCancellation()
  let engine=AVAudioEngine();let input=engine.inputNode;let format=input.outputFormat(forBus:0)
  guard format.sampleRate>0,format.channelCount>0 else {decoder.cancel();throw SayseeError.message("没有可用麦克风，请连接设备后重试。")}
  let decoder=self.decoder;let id=captureGate.begin(),activity=CaptureActivity()
  input.installTap(onBus:0,bufferSize:1024,format:format) { buffer,_ in
   guard let channels=buffer.floatChannelData else {return}
   let n=Int(buffer.frameLength),count=Int(buffer.format.channelCount)
   var mono=[Float](repeating:0,count:n)
   for c in 0..<count {for i in 0..<n {mono[i]+=channels[c][i]/Float(count)}}
   decoder.accept(mono,rate:Int32(buffer.format.sampleRate),session:sessionID)
   if let speaking=activity.update(mono,rate:buffer.format.sampleRate) {
    Task { @MainActor [weak self] in
     guard let self=self,self.captureGate.accepts(id) else {return}
     self.onActivity?(speaking)
    }
   }
  }
  self.engine=engine;engine.prepare()
  do {try engine.start()} catch {stopCapture();decoder.cancel();throw error}
  observer=NotificationCenter.default.addObserver(forName:.AVAudioEngineConfigurationChange,object:engine,queue:.main) { [weak self] _ in
   Task { @MainActor in
    guard let self=self,self.captureGate.accepts(id) else {return}
    self.onInterruption?("麦克风设备发生变化，录音已停止。请检查设备后重新录音；已识别的原文会保留。")
   }
  }
 }
 private func stopCapture() {captureGate.cancel();onActivity?(false);if let observer=observer {NotificationCenter.default.removeObserver(observer);self.observer=nil};if let e=engine {e.inputNode.removeTap(onBus:0);e.stop()};engine=nil}
 func endCapture() {let tick=DiagnosticLog.now();stopCapture();DiagnosticLog.emit("capture_stopped",session:activeSession,since:tick)}
 func stop() async throws -> String {if engine != nil {endCapture()};return try await decoder.finish()}
 func cancel() {stopCapture();decoder.cancel()}
}
