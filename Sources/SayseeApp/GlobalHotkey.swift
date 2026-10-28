import AppKit
import ApplicationServices
import SayseeCore
import IOKit.hid
final class GlobalHotkey {
 var onToggle: (()->Void)?
 var onCancel: (()->Void)?
 var onStatus: ((String)->Void)?
 private var tap: CFMachPort?
 private var runLoopSource: CFRunLoopSource?
 private var gesture=FnGesture()
 private var hidManager:IOHIDManager?
 private var hidFnAvailable=false
 private var hidPressed=false
 func start() -> Bool {
  stop();gesture=FnGesture();startHID()
  let events=(1<<CGEventType.flagsChanged.rawValue)|(1<<CGEventType.keyDown.rawValue)|(1<<CGEventType.keyUp.rawValue)
  for (location,label) in [(CGEventTapLocation.cghidEventTap,"hid"),(.cgSessionEventTap,"session")] {
   guard let next=CGEvent.tapCreate(tap:location,place:.headInsertEventTap,options:.listenOnly,eventsOfInterest:CGEventMask(events),callback:{_,type,event,context in
    let owner=Unmanaged<GlobalHotkey>.fromOpaque(context!).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
     owner.gesture=FnGesture();DiagnosticLog.emit("hotkey_tap_disabled",metadata:["reason":type == .tapDisabledByTimeout ? "timeout":"user_input"])
     if let tap=owner.tap {CGEvent.tapEnable(tap:tap,enable:true)}
     return Unmanaged.passUnretained(event)
    }
    owner.handle(type,event);return Unmanaged.passUnretained(event)
   },userInfo:Unmanaged.passUnretained(self).toOpaque()) else {continue}
   tap=next;runLoopSource=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,next,0)
   CFRunLoopAddSource(CFRunLoopGetMain(),runLoopSource,.commonModes);CGEvent.tapEnable(tap:next,enable:true)
   DiagnosticLog.emit("hotkey_ready",metadata:["backend":label,"listen_permission":"\(CGPreflightListenEventAccess())","ax_permission":"\(AXIsProcessTrusted())"])
   onStatus?("监听已连接（\(hidFnAvailable ? "Fn HID + " : "")\(label)），等待 Fn 事件");return true
  }
  DiagnosticLog.emit("hotkey_unavailable",metadata:["listen_permission":"\(CGPreflightListenEventAccess())","ax_permission":"\(AXIsProcessTrusted())"])
  onStatus?("监听建立失败，请检查输入监控权限并重启应用");return false
 }
 private func handle(_ type:CGEventType,_ event:CGEvent) {
  let code=Int(event.getIntegerValueField(.keyboardEventKeycode))
  let kind:KeyEventKind=type == .flagsChanged ? .flags:(type == .keyDown ? .down:.up)
  let fn=event.flags.contains(.maskSecondaryFn)
  let modifiers=event.flags.intersection([.maskCommand,.maskShift,.maskAlternate,.maskControl])
  if code==63 {
   DiagnosticLog.emit("hotkey_fn_event",metadata:["key_code":"63","fn_down":"\(fn)","modifiers":"\(modifiers.rawValue)","event_kind":"\(kind)"])
   DispatchQueue.main.async { [weak self] in self?.onStatus?("收到 Fn：\(kind)，Fn 标志 \(fn ? "按下":"松开")") }
  }
  let fallback=code==49 && type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat)==0 && modifiers == [.maskCommand,.maskShift] && !fn
  let trigger:Bool
  if hidFnAvailable {
   if type == .keyDown && code != 63 {gesture.keyDown()}
   if hidPressed && type == .flagsChanged && !modifiers.isEmpty {_ = gesture.update(fn:true,other:true)}
   trigger=false
  } else {trigger=gesture.handle(keyCode:code,kind:kind,fnFlag:fn,other:!modifiers.isEmpty)}
  if trigger || fallback {
   DiagnosticLog.emit("hotkey_trigger",metadata:["reason":fallback ? "cmd_shift_space":"fn"])
   // Never perform capture, file IO, or AX queries inside the event-tap callback.
   DispatchQueue.main.async { [weak self] in self?.onToggle?() }
  }
  if type == .keyDown && code==53 {DispatchQueue.main.async { [weak self] in self?.onCancel?() }}
 }
 private func startHID() {
  let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOOptionBits(kIOHIDOptionsTypeNone))
  IOHIDManagerSetDeviceMatchingMultiple(manager,[[kIOHIDDeviceUsagePageKey:1,kIOHIDDeviceUsageKey:6],[kIOHIDDeviceUsagePageKey:255,kIOHIDDeviceUsageKey:3]] as CFArray)
  // Receive only the Apple Fn element. Ordinary typing is never logged.
  IOHIDManagerSetInputValueMatchingMultiple(manager,[[kIOHIDElementUsagePageKey:255,kIOHIDElementUsageKey:3]] as CFArray)
  let context=Unmanaged.passUnretained(self).toOpaque()
  IOHIDManagerRegisterInputValueCallback(manager,{context,result,_,value in
   guard result==kIOReturnSuccess,let context=context else {return}
   let owner=Unmanaged<GlobalHotkey>.fromOpaque(context).takeUnretainedValue()
   owner.handleHID(value)
  },context)
  IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
  let result=IOHIDManagerOpen(manager,IOOptionBits(kIOHIDOptionsTypeNone))
  guard result==kIOReturnSuccess else {
   IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
   DiagnosticLog.emit("hotkey_hid_unavailable",metadata:["error_code":"\(result)"]);return
  }
  hidManager=manager
  if let devices=IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
   hidFnAvailable=devices.contains {device in
    let elements=IOHIDDeviceCopyMatchingElements(device,[kIOHIDElementUsagePageKey:255,kIOHIDElementUsageKey:3] as CFDictionary,IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement]
    return !(elements ?? []).isEmpty
   }
  }
  DiagnosticLog.emit("hotkey_hid_ready",metadata:["status":hidFnAvailable ? "fn_element_found":"no_fn_element"])
 }
 private func handleHID(_ value:IOHIDValue) {
  let element=IOHIDValueGetElement(value)
  let page=IOHIDElementGetUsagePage(element),usage=IOHIDElementGetUsage(element)
  guard page==255,usage==3 else {return}
  if !hidFnAvailable {gesture=FnGesture();hidFnAvailable=true}
  let down=IOHIDValueGetIntegerValue(value) != 0
  hidPressed=down
  let modifiers=CGEventSource.flagsState(.combinedSessionState).intersection([.maskCommand,.maskShift,.maskAlternate,.maskControl])
  DiagnosticLog.emit("hotkey_fn_event",metadata:["backend":"iokit_hid","fn_down":"\(down)","modifiers":"\(modifiers.rawValue)"])
  let trigger=gesture.handleHID(page:page,usage:usage,value:down ? 1:0,other:!modifiers.isEmpty) ?? false
  DispatchQueue.main.async { [weak self] in self?.onStatus?("收到 Fn HID：\(down ? "按下":"松开")") }
  if trigger {
   DiagnosticLog.emit("hotkey_trigger",metadata:["reason":"fn_hid"])
   DispatchQueue.main.async { [weak self] in self?.onToggle?() }
  }
 }
 private func stop() {
  if let manager=hidManager {IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue);IOHIDManagerClose(manager,IOOptionBits(kIOHIDOptionsTypeNone))};hidManager=nil;hidFnAvailable=false;hidPressed=false
  if let source=runLoopSource {CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes)}
  if let tap=tap {CFMachPortInvalidate(tap)}
  runLoopSource=nil;tap=nil
 }
 deinit {stop()}
}
