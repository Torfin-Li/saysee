import AppKit
import Combine
import SayseeCore
@MainActor final class SessionController: ObservableObject {
 enum Phase {case idle,preparing,recording,thinking,result,success,failed}
 @Published var phase:Phase = .idle
 @Published var voiceActive=false
 @Published var elapsed=0
 @Published var raw=""
 @Published var output=""
 @Published var errorMessage=""
 @Published var hotkeyReady=false
 @Published var hotkeyStatus="等待监听"
 @Published var diagnosingHotkey=false
 var updateOverlay: (()->Void)?
 let audio=SpeechEngine(),hotkey=GlobalHotkey()
 private var gate=SessionGate(),work:Task<Void,Never>?,timer:Timer?
 private var target:TextTarget?
 private var traceID=UUID()
 private var stoppedAt:Double?
 init() {
  LegacySettingsMigration.remove(from:.standard)
  UserDefaults.standard.register(defaults:["deepSeekModel":"deepseek-flash"])
  audio.decoder.onFailure={ [weak self] message in Task { @MainActor in guard let self=self,self.phase == .recording else {return};self.cancel();self.errorMessage=message;self.setPhase(.failed) } }
  audio.onActivity={ [weak self] active in
   guard let self=self else {return}
   self.voiceActive=active && self.phase == .recording
  }
  audio.onInterruption={ [weak self] message in self?.interrupt(message) }
  hotkey.onStatus={ [weak self] status in self?.hotkeyStatus=status }
  hotkey.onToggle={ [weak self] in
   guard let self=self else {return}
   if self.diagnosingHotkey {self.hotkeyStatus="触发成功；已拦下本次操作，仅用于检测";return}
   self.toggle()
  }
  hotkey.onCancel={ [weak self] in self?.cancel() }
 }
 func enableHotkey() {hotkeyReady=hotkey.start()}
 func configuration() -> RewriteConfiguration {
  .init(model:UserDefaults.standard.string(forKey:"deepSeekModel") ?? "deepseek-flash")
 }
 func toggle() {DiagnosticLog.emit("toggle_requested",session:traceID,metadata:["status":"\(phase)"]);if phase == .recording {stop()} else if [.idle,.result,.success,.failed].contains(phase) {start()} }
 func setPhase(_ value:Phase) {if value != .recording {voiceActive=false};phase=value;DiagnosticLog.emit("phase",session:traceID,metadata:["status":"\(value)"]);updateOverlay?()}
 func start() {
  work?.cancel();let id=gate.begin();traceID=id;stoppedAt=nil;let started=DiagnosticLog.now();DiagnosticLog.emit("capture_start_requested",session:id);raw="";output="";errorMessage="";elapsed=0;target=nil;setPhase(.preparing)
  work=Task { [weak self] in
   guard let self=self else {return}
   do {
    // Validate credentials before recording so an avoidable configuration error never consumes a take.
    if await Keychain.read().isEmpty {throw SayseeError.message("请先在设置中保存 DeepSeek API Key。")}
    try Task.checkCancellation()
    try await self.audio.start(sessionID:id);guard self.gate.accepts(id),!Task.isCancelled else {return}
    DiagnosticLog.emit("capture_ready",session:id,since:started);self.setPhase(.recording);self.timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in Task { @MainActor in guard let self=self,self.phase == .recording else {return};self.elapsed+=1;if self.elapsed>=300 {self.stop()} } }
   } catch {if self.gate.accepts(id) {self.audio.cancel();self.errorMessage=error.localizedDescription;self.setPhase(.failed)}}
  }
 }
 func interrupt(_ message:String) {
  guard phase == .recording else {return}
  timer?.invalidate();timer=nil;let id=gate.begin();work?.cancel();setPhase(.thinking)
  work=Task { [weak self] in
   guard let self=self else {return};let text=(try? await self.audio.stop()) ?? ""
   guard self.gate.accepts(id),!Task.isCancelled else {return}
   self.raw=text;self.target=nil;self.errorMessage=message;self.setPhase(.failed)
  }
 }
 func stop() {
  guard phase == .recording else {return};timer?.invalidate();timer=nil
  // Snapshot at the end of speech, then recheck immediately before paste.
  stoppedAt=DiagnosticLog.now();DiagnosticLog.emit("stop_requested",session:traceID)
  audio.endCapture()
  let focusStart=DiagnosticLog.now();target=TextDelivery.focus();DiagnosticLog.emit("focus_snapshot",session:traceID,since:focusStart)
  let id=gate.begin();let session=traceID;let stopTime=stoppedAt!;setPhase(.thinking)
  work=Task { [weak self] in
   guard let self=self else {return}
   do {
   let text=try await self.audio.stop()
   guard self.gate.accepts(id),!Task.isCancelled else {return};self.raw=text
   DiagnosticLog.emit("stt_complete",session:session,since:stopTime,elapsedSince:stopTime,metadata:["input_chars":"\(text.count)"])
   await self.process(text,id:id)
   } catch {
    DiagnosticLog.emit("stt_failed",session:session,elapsedSince:stopTime,metadata:["error_domain":(error as NSError).domain,"error_code":"\((error as NSError).code)"])
    if self.gate.accepts(id),!Task.isCancelled {self.errorMessage=error.localizedDescription;self.setPhase(.failed)}
   }
  }
 }
 private func process(_ text:String,id:UUID) async {
  let session=traceID,stopTime=stoppedAt
  var stage="configuration"
  do {
   guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {throw SayseeError.message("没有识别到语音，请重新录音。")}
   let config=configuration()
   stage="auth";let authStart=DiagnosticLog.now(),token=await Keychain.read()
   guard !token.isEmpty else {throw SayseeError.message("请先在设置中保存 DeepSeek API Key。")}
   DiagnosticLog.emit("auth_wait_complete",session:session,since:authStart,elapsedSince:stopTime)
   try Task.checkCancellation();stage="llm";let llmStart=DiagnosticLog.now()
   DiagnosticLog.emit("llm_started",session:session,elapsedSince:stopTime,metadata:["provider":"deepSeek","model":config.model,"input_chars":"\(text.count)","prompt_version":"distilled-v4","thinking":"disabled"])
   let result=try await RewriteClient.rewrite(text,configuration:config,token:token)
   DiagnosticLog.emit("llm_complete",session:session,since:llmStart,elapsedSince:stopTime,metadata:["provider":"deepSeek","model":config.model,"output_chars":"\(result.count)"])
   guard gate.accepts(id),!Task.isCancelled else {return};output=result
   stage="delivery";let deliveryStart=DiagnosticLog.now()
   let pasted=TextDelivery.deliver(result,expected:target)
   DiagnosticLog.emit("delivery_complete",session:session,since:deliveryStart,elapsedSince:stopTime,metadata:["status":pasted ? "paste_dispatched":"clipboard_card"])
   DiagnosticLog.emit("turn_complete",session:session,since:stopTime,elapsedSince:stopTime)
   setPhase(pasted ? .success:.result)
   if pasted {try? await Task.sleep(nanoseconds:1_400_000_000);if gate.accepts(id),phase == .success {setPhase(.idle)}}
  } catch {DiagnosticLog.emit("turn_failed",session:session,elapsedSince:stopTime,metadata:["reason":stage,"error_domain":(error as NSError).domain,"error_code":"\((error as NSError).code)"]);if gate.accepts(id),!Task.isCancelled {errorMessage=error.localizedDescription;setPhase(.failed)}}
 }
 func retry() {guard !raw.isEmpty else {start();return};let id=gate.begin();stoppedAt=DiagnosticLog.now();setPhase(.thinking);work=Task{await process(raw,id:id)}}
 func useRaw() {output=raw;TextDelivery.copy(raw);setPhase(.result)}
 func cancel() {DiagnosticLog.emit("turn_cancelled",session:traceID);gate.cancel();work?.cancel();work=nil;timer?.invalidate();timer=nil;audio.cancel();setPhase(.idle)}
 func close() {cancel()}
 func copyResult() {TextDelivery.copy(output)}
 func checkConnection() async -> String {
  do {
   let token=await Keychain.read()
   guard !token.isEmpty else {throw SayseeError.message("请先在设置中保存 DeepSeek API Key。")}
   let result=try await RewriteClient.rewrite("明天下午三点开会先不要发送邀请",configuration:configuration(),token:token)
   return "连接成功：\(result)"
  } catch {return error.localizedDescription}
 }
}
