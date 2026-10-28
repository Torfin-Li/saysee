import AppKit
import SwiftUI
import AVFoundation
import SayseeCore

@main enum SayseeLauncher {
 private static var instanceLock:ProcessLock?
 static func main() {
  let args=CommandLine.arguments
  if let index=args.firstIndex(of:"--check-stt-paced"),args.count>index+1 {
   let path=args[index+1],semaphore=DispatchSemaphore(value:0)
   Task.detached {
    do {try await STTValidation.paced(path)} catch {fputs("\(error.localizedDescription)\n",stderr);DiagnosticLog.flush();exit(1)}
    DiagnosticLog.flush();semaphore.signal()
   };semaphore.wait();return
  }
  if let index=args.firstIndex(of:"--check-stt") {
   let paths=Array(args.dropFirst(index+1)),semaphore=DispatchSemaphore(value:0)
   Task.detached {
    do {try await STTValidation.run(paths)} catch {fputs("\(error.localizedDescription)\n",stderr);DiagnosticLog.flush();exit(1)}
    DiagnosticLog.flush();semaphore.signal()
   };semaphore.wait();return
  }
  if let index=args.firstIndex(of:"--transcribe"),args.count>index+1 {
   let semaphore=DispatchSemaphore(value:0),path=args[index+1]
   Task.detached {
    do {
     let decoder=NativeDecoder(),session=UUID();try await decoder.begin(sessionID:session)
     let file=try AVAudioFile(forReading:URL(fileURLWithPath:path)),format=file.processingFormat
     guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(file.length)) else {throw SayseeError.message("无法读取测试音频")}
     try file.read(into:buffer);guard let channels=buffer.floatChannelData else {throw SayseeError.message("测试音频必须为 PCM")}
     let n=Int(buffer.frameLength);var mono=[Float](repeating:0,count:n)
     for c in 0..<Int(format.channelCount) {for i in 0..<n {mono[i]+=channels[c][i]/Float(format.channelCount)}}
     decoder.accept(mono,rate:Int32(format.sampleRate),session:session)
     print(try await decoder.finish());DiagnosticLog.flush()
    }catch {fputs("\(error.localizedDescription)\n",stderr);DiagnosticLog.flush();exit(1)}
    semaphore.signal()
   };semaphore.wait();return
  }
  let lockDirectory=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Saysee")
  do {
   try FileManager.default.createDirectory(at:lockDirectory,withIntermediateDirectories:true)
   instanceLock=try ProcessLock(url:lockDirectory.appendingPathComponent("instance.lock"))
  } catch {
   DiagnosticLog.emit("duplicate_instance",metadata:["status":"existing_instance_kept"])
   let path=lockDirectory.appendingPathComponent("instance.lock")
   if let text=try? String(contentsOf:path),let pid=Int32(text) {NSRunningApplication(processIdentifier:pid)?.activate(options:[.activateIgnoringOtherApps])}
   DistributedNotificationCenter.default().postNotificationName(Notification.Name("com.saysee.showSettings"),object:nil,userInfo:nil,deliverImmediately:true)
   DiagnosticLog.flush();return
  }
  DiagnosticLog.emit("app_started")
  let app=NSApplication.shared;let delegate=AppDelegate();app.delegate=delegate;app.run()
 }
}
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {
 private var status:NSStatusItem!,controller:SessionController!,overlay:OverlayWindow!,settings:NSWindow!
 private var keyMonitor:Any?
 private var settingsObserver:NSObjectProtocol?
 func applicationDidFinishLaunching(_ notification:Notification) {
  NSApp.setActivationPolicy(.accessory)
  let mainMenu=NSMenu(),appItem=NSMenuItem(),appMenu=NSMenu()
  appMenu.addItem(withTitle:"退出 Saysee",action:#selector(quit),keyEquivalent:"q").target=self
  appItem.submenu=appMenu;mainMenu.addItem(appItem)
  let editItem=NSMenuItem(),editMenu=NSMenu(title:"编辑")
  editMenu.addItem(withTitle:"撤销",action:Selector(("undo:")),keyEquivalent:"z")
  let redo=editMenu.addItem(withTitle:"重做",action:Selector(("redo:")),keyEquivalent:"z");redo.keyEquivalentModifierMask=[.command,.shift]
  editMenu.addItem(.separator())
  editMenu.addItem(withTitle:"剪切",action:#selector(NSText.cut(_:)),keyEquivalent:"x")
  editMenu.addItem(withTitle:"复制",action:#selector(NSText.copy(_:)),keyEquivalent:"c")
  editMenu.addItem(withTitle:"粘贴",action:#selector(NSText.paste(_:)),keyEquivalent:"v")
  editMenu.addItem(withTitle:"全选",action:#selector(NSText.selectAll(_:)),keyEquivalent:"a")
  editItem.submenu=editMenu;mainMenu.addItem(editItem);NSApp.mainMenu=mainMenu
  controller=SessionController();overlay=OverlayWindow(controller:controller);controller.updateOverlay={ [weak self] in self?.overlay.update() }
  status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
  status.button?.image=NSImage(systemSymbolName:"waveform",accessibilityDescription:"Saysee 语音输入")
  let menu=NSMenu();menu.addItem(withTitle:"开始 / 结束录音",action:#selector(toggle),keyEquivalent:"");menu.addItem(withTitle:"设置…",action:#selector(showSettings),keyEquivalent:",");menu.addItem(.separator());menu.addItem(withTitle:"退出 Saysee",action:#selector(quit),keyEquivalent:"q");for item in menu.items {item.target=self};status.menu=menu
  settings=NSWindow(contentRect:NSRect(x:0,y:0,width:780,height:570),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
  settings.title="Saysee 设置";settings.isReleasedWhenClosed=false;settings.contentView=NSHostingView(rootView:SettingsView(controller:controller));settings.center()
  keyMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
   if event.keyCode==53 {self?.controller.cancel();return nil};return event
  }
  settingsObserver=DistributedNotificationCenter.default().addObserver(forName:Notification.Name("com.saysee.showSettings"),object:nil,queue:.main) { [weak self] _ in self?.showSettings() }
  controller.enableHotkey();showSettings()
 }
 @objc func toggle(){controller.toggle()}
 @objc func showSettings(){NSApp.activate(ignoringOtherApps:true);settings.makeKeyAndOrderFront(nil)}
 @objc func quit(){NSApp.terminate(nil)}
 func applicationWillTerminate(_ notification:Notification) {
  controller?.cancel()
  DiagnosticLog.emit("app_terminated");DiagnosticLog.flush()
 }
 func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
}
